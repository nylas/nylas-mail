path = require 'path'

module.exports = (grunt) ->
  {cp} = require('./task-helpers')(grunt)

  grunt.registerTask 'copy-info-plist', 'Copy plist', ->
    contentsDir = grunt.config.get('nylasGruntConfig.contentsDir')
    plistPath = path.join(contentsDir, 'Info.plist')
    helperPlistPath = path.join(contentsDir, 'Frameworks/Atom Helper.app/Contents/Info.plist')

    # Copy custom plist files
    cp 'build/resources/mac/nylas-Info.plist', plistPath
    cp 'build/resources/mac/helper-Info.plist',  helperPlistPath
