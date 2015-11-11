path = require 'path'

module.exports = (grunt) ->
  grunt.registerTask 'set-exe-icon', 'Set icon of the exe', ->
    done = @async()

    shellAppDir = grunt.config.get('nylasGruntConfig.shellAppDir')
    shellExePath = path.join(shellAppDir, 'nylas.exe')
    iconPath = path.resolve('build', 'resources', 'win', 'nylas.ico')

    rcedit = require('rcedit')
    rcedit(shellExePath, {'icon': iconPath}, done)
