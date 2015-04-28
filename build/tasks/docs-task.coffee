path = require 'path'
Handlebars = require 'handlebars'
marked = require 'marked'
cjsxtransform = require 'coffee-react-transform'
rimraf = require 'rimraf'

fs = require 'fs-plus'
_ = require 'underscore-plus'

donna = require 'donna'
tello = require 'tello'

moduleBlacklist = [
  'space-pen'
]

marked.setOptions
  highlight: (code) ->
    require('highlight.js').highlightAuto(code).value

standardClassURLRoot = 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/'

standardClasses = [
  'string',
  'object',
  'array',
  'function',
  'number',
  'date',
  'error',
  'boolean',
  'null',
  'undefined',
  'json',
  'set',
  'map',
  'typeerror',
  'syntaxerror',
  'referenceerror',
  'rangeerror'
]

thirdPartyClasses = {
  'react.component': 'https://facebook.github.io/react/docs/component-api.html',
  'promise': 'https://github.com/petkaantonov/bluebird/blob/master/API.md',
  'range': 'https://developer.mozilla.org/en-US/docs/Web/API/Range',
  'selection': 'https://developer.mozilla.org/en-US/docs/Web/API/Selection',
  'node': 'https://developer.mozilla.org/en-US/docs/Web/API/Node',
}

module.exports = (grunt) ->
  getClassesToInclude = ->
    modulesPath = path.resolve(__dirname, '..', '..', 'internal_packages')
    classes = {}
    fs.traverseTreeSync modulesPath, (modulePath) ->
      # Don't traverse inside dependencies
      return false if modulePath.match(/node_modules/g)

      # Don't traverse blacklisted packages (that have docs, but we don't want to include)
      return false if path.basename(modulePath) in moduleBlacklist
      return true unless path.basename(modulePath) is 'package.json'
      return true unless fs.isFileSync(modulePath)

      apiPath = path.join(path.dirname(modulePath), 'api.json')
      if fs.isFileSync(apiPath)
        _.extend(classes, grunt.file.readJSON(apiPath).classes)
      true
    classes

  sortClasses = (classes) ->
    sortedClasses = {}
    for className in Object.keys(classes).sort()
      sortedClasses[className] = classes[className]
    sortedClasses

  processFields = (json, fields = [], tasks = []) ->
    if json instanceof Array
      for val in json
        processFields(val, fields, tasks)
    else
      for key, val of json
        if key in fields
          for task in tasks
            val = task(val)
          json[key] = val
        if _.isObject(val)
          processFields(val, fields, tasks)


  grunt.registerTask 'build-docs', 'Builds the API docs in src', ->
    done = @async()

    # Convert CJSX into coffeescript that can be read by Donna

    docsOutputDir = grunt.config.get('docsOutputDir')
    cjsxOutputDir = path.join(docsOutputDir, 'temp-cjsx')
    rimraf cjsxOutputDir, ->
      fs.mkdir(cjsxOutputDir)
      srcPath = path.resolve(__dirname, '..', '..', 'src')
      fs.traverseTreeSync srcPath, (file) ->
        if path.extname(file) is '.cjsx'
          transformed = cjsxtransform(grunt.file.read(file))
          # Only attempt to parse this file as documentation if it contains
          # real Coffeescript classes.
          if transformed.indexOf('\nclass ') > 0
            grunt.file.write(path.join(cjsxOutputDir, path.basename(file)[0..-5]+'coffee'), transformed)
        true

      # Process coffeescript source

      metadata = donna.generateMetadata(['.', cjsxOutputDir])
      api = tello.digest(metadata)
      _.extend(api.classes, getClassesToInclude())
      api.classes = sortClasses(api.classes)

      apiJson = JSON.stringify(api, null, 2)
      apiJsonPath = path.join(docsOutputDir, 'api.json')
      grunt.file.write(apiJsonPath, apiJson)
      done()

  grunt.registerTask 'render-docs', 'Builds html from the API docs', ->
    docsOutputDir = grunt.config.get('docsOutputDir')
    apiJsonPath = path.join(docsOutputDir, 'api.json')

    templatesPath = path.resolve(__dirname, '..', '..', 'docs-templates')
    grunt.file.recurse templatesPath, (abspath, root, subdir, filename) ->
      if filename[0] is '_' and path.extname(filename) is '.html'
        Handlebars.registerPartial(filename[0..-6], grunt.file.read(abspath))

    templatePath = path.join(templatesPath, 'class.html')
    template = Handlebars.compile(grunt.file.read(templatePath))

    api = JSON.parse(grunt.file.read(apiJsonPath))
    classnames = _.map Object.keys(api.classes), (s) -> s.toLowerCase()
    console.log("Generating HTML for #{classnames.length} classes")

    expandTypeReferences = (val) ->
      refRegex = /{([\w.]*)}/g
      while (match = refRegex.exec(val)) isnt null
        classname = match[1].toLowerCase()
        url = false
        if classname in standardClasses
          url = standardClassURLRoot+classname
        else if thirdPartyClasses[classname]
          url = thirdPartyClasses[classname]
        else if classname in classnames
          url = "./#{classname}.html"
        else
          console.warn("Cannot find class named #{classname}")

        if url
          val = val.replace(match[0], "<a href='#{url}'>#{match[1]}</a>")
      val

    expandFuncReferences = (val) ->
      refRegex = /{([\w]*)?::([\w]*)}/g
      while (match = refRegex.exec(val)) isnt null
        [text, a, b] = match
        url = false
        if a and b
          url = "#{a}.html##{b}"
          label = "#{a}::#{b}"
        else
          url = "##{b}"
          label = "#{b}"
        if url
          val = val.replace(text, "<a href='#{url}'>#{label}</a>")
      val

    for classname, contents of api.classes
      processFields(contents, ['description'], [marked, expandTypeReferences, expandFuncReferences])
      processFields(contents, ['type'], [expandTypeReferences])

      result = template(contents)
      resultPath = path.join(docsOutputDir, "#{classname}.html")
      grunt.file.write(resultPath, result)
