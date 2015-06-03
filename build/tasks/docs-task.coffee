path = require 'path'
Handlebars = require 'handlebars'
marked = require 'meta-marked'
cjsxtransform = require 'coffee-react-transform'
rimraf = require 'rimraf'

fs = require 'fs-plus'
_ = require 'underscore'

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

  {cp, mkdir, rm} = require('./task-helpers')(grunt)

  relativePathForClass = (classname) ->
    classname+'.html'

  outputPathFor = (relativePath) ->
    docsOutputDir = grunt.config.get('docsOutputDir')
    path.join(docsOutputDir, relativePath)

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
      console.log('---- Done with Donna ----')

      try
        api = tello.digest(metadata)
      catch e
        console.log(e.stack)

      console.log('---- Done with Tello ----')
      _.extend(api.classes, getClassesToInclude())
      api.classes = sortClasses(api.classes)

      apiJson = JSON.stringify(api, null, 2)
      apiJsonPath = path.join(docsOutputDir, 'api.json')
      grunt.file.write(apiJsonPath, apiJson)
      done()

  grunt.registerTask 'render-docs', 'Builds html from the API docs', ->
    docsOutputDir = grunt.config.get('docsOutputDir')

    # Parse API reference Markdown

    classes = []
    apiJsonPath = path.join(docsOutputDir, 'api.json')
    apiJSON = JSON.parse(grunt.file.read(apiJsonPath))

    for classname, contents of apiJSON.classes
      # Parse a "@Section" out of the description if one is present
      sectionRegex = /Section: ?([\w ]*)(?:$|\n)/
      section = 'General'
      console.log(contents.description)
      match = sectionRegex.exec(contents.description)
      if match
        contents.description = contents.description.replace(match[0], '')
        section = match[1].trim()

      # Replace superClass "React" with "React.Component". The Coffeescript Lexer
      # is so bad.
      if contents.superClass is "React"
        contents.superClass = "React.Component"

      classes.push({
        name: classname
        documentation: contents
        section: section
      })

    # Parse Article Markdown

    # Build Sidebar metadata we can hand off to each of the templates to
    # generate the sidebar

    referenceSections = {}
    for klass in classes
      section = referenceSections[klass.section]
      if not section
        section = {name: klass.section, classes: []}
        referenceSections[klass.section] = section
      section.classes.push(klass)

    preferredSectionOrdering = ['General', 'Component Kit', 'Models', 'Stores', 'Database', 'Drafts', 'Atom']
    sorted = []
    for key in preferredSectionOrdering
      if referenceSections[key]
        sorted.push(referenceSections[key])
        delete referenceSections[key]
    for key, val of referenceSections
      sorted.push(val)

    api_sidebar_meta = sorted.map ({name, classes}) ->
      name: name
      items: classes.map ({name}) -> {name: name, link: relativePathForClass(name), slug: name.toLowerCase() }

    console.log("Here's the sidebar info:")
    console.log(api_sidebar_meta.toString())

    docsOutputDir = grunt.config.get('docsOutputDir')
    sidebarJson = JSON.stringify(api_sidebar_meta, null, 2)
    sidebarPath = path.join(docsOutputDir, '_sidebar.json')
    grunt.file.write(sidebarPath, sidebarJson)



    # Prepare to render by loading handlebars partials

    templatesPath = path.resolve(__dirname, '..', '..', 'docs-templates')
    grunt.file.recurse templatesPath, (abspath, root, subdir, filename) ->
      if filename[0] is '_' and path.extname(filename) is '.html'
        Handlebars.registerPartial(filename[0..-6], grunt.file.read(abspath))

    # Render Helpers

    knownClassnames = {}
    for classname, val of apiJSON.classes
      knownClassnames[classname.toLowerCase()] = val

    expandTypeReferences = (val) ->
      refRegex = /{([\w.]*)}/g
      while (match = refRegex.exec(val)) isnt null
        term = match[1].toLowerCase()
        label = match[1]
        url = false
        if term in standardClasses
          url = standardClassURLRoot+term
        else if thirdPartyClasses[term]
          url = thirdPartyClasses[term]
        else if knownClassnames[term]
          url = relativePathForClass(term)
        else
          console.warn("Cannot find class named #{term}")

        if url
          val = val.replace(match[0], "<a href='#{url}'>#{label}</a>")
      val

    expandFuncReferences = (val) ->
      refRegex = /{([\w]*)?::([\w]*)}/g
      while (match = refRegex.exec(val)) isnt null
        [text, a, b] = match
        url = false
        if a and b
          url = "#{relativePathForClass(a)}##{b}"
          label = "#{a}::#{b}"
        else
          url = "##{b}"
          label = "#{b}"
        if url
          val = val.replace(text, "<a href='#{url}'>#{label}</a>")
      val

    # Render Class Pages

    classTemplatePath = path.join(templatesPath, 'class.html')
    classTemplate = Handlebars.compile(grunt.file.read(classTemplatePath))

    for {name, documentation, section} in classes
      # Recursively process `description` and `type` fields to process markdown,
      # expand references to types, functions and other files.
      processFields(documentation, ['description'], [marked.noMeta, expandTypeReferences, expandFuncReferences])
      processFields(documentation, ['type'], [expandTypeReferences])

      result = classTemplate({name, documentation, section})
      grunt.file.write(outputPathFor(relativePathForClass(name)), result)
