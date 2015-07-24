path = require 'path'

module.exports = (grunt) ->
  grunt.registerTask 'set-exe-icon', 'Set icon of the exe', ->
    done = @async()

    shellAppDir = grunt.config.get('atom.shellAppDir')
    shellExePath = path.join(shellAppDir, 'edgehill.exe')
    iconPath = path.resolve('build', 'resources', 'win', 'edgehill.ico')

    rcedit = require('rcedit')
    rcedit(shellExePath, {'icon': iconPath}, done)
