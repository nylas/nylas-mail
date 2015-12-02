fs = require 'fs-plus'
path = require 'path'

module.exports = (grunt) ->
  {cp, mkdir, rm} = require('./task-helpers')(grunt)
  rootDir = path.resolve(path.join('resources', 'nylas'))

  copyArcFiles = ->
    cp path.join(rootDir, 'arc-N1', '.arcconfig'), '.arcconfig'
    cp path.join(rootDir, 'arc-N1', '.arclint'), '.arclint'
    cp path.join(rootDir, 'arc-N1', 'arclib'), 'arclib'

  copySourceExtensions = ->
    cp path.join(rootDir, 'src'), 'src'

  linkPlugins = ->
    for plugin in fs.readdirSync(path.join(rootDir, 'packages'))
      from = path.join(rootDir, 'packages', plugin)
      to = path.join(path.resolve('internal_packages'), plugin)
      if not fs.existsSync(to)
        grunt.log.writeln "Adding '#{plugin}' to internal_packages"
        fs.symlinkSync(from, to, 'dir')

  desc = 'Adds in proprietary Nylas packages, fonts, and sounds to N1'
  grunt.registerTask 'add-nylas-build-resources', desc, ->
    canaryFileExists = fs.existsSync(path.join(rootDir, "README.md"))
    if not canaryFileExists
      grunt.log.writeln "No extra Nylas resources added"
      return
    else
      grunt.log.writeln "Found proprietary Nylas plugins"
      copyArcFiles()
      copySourceExtensions()
      linkPlugins()
