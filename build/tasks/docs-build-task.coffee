path = require 'path'
cjsxtransform = require 'coffee-react-transform'
rimraf = require 'rimraf'

fs = require 'fs-plus'
_ = require 'underscore'

donna = require 'donna'
tello = require 'tello'

moduleBlacklist = [
  'space-pen'
]

module.exports = (grunt) ->
  {cp, mkdir, rm} = require('./task-helpers')(grunt)

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
