asar = require 'asar'
fs = require 'fs'
path = require 'path'

module.exports = (grunt) ->
  {cp, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'generate-asar', 'Generate asar archive for the app', ->
    done = @async()

    unpack = [
      '*.node'
      '**/vendor/**'
      '**/examples/**'
      '**/src/tasks/**'
      '**/node_modules/spellchecker/**'
    ]
    unpack = "{#{unpack.join(',')}}"

    appDir = grunt.config.get('nylasGruntConfig.appDir')
    unless fs.existsSync(appDir)
      grunt.log.error 'The app has to be built before generating asar archive.'
      return done(false)

    asar.createPackageWithOptions appDir, path.resolve(appDir, '..', 'app.asar'), {unpack}, (err) ->
      return done(err) if err?

      rm appDir
      fs.renameSync path.resolve(appDir, '..', 'new-app'), appDir

      done()
