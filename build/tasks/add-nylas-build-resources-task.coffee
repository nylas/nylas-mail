fs = require 'fs-plus'
path = require 'path'

module.exports = (grunt) ->
  {cp, mkdir, rm} = require('./task-helpers')(grunt)
  rootDir = path.resolve(path.join('../', 'internal_packages', 'pro'))

  copyArcFiles = ->
    cp path.join(rootDir, 'arc-N1', '.arcconfig'), '.arcconfig'
    cp path.join(rootDir, 'arc-N1', '.arclint'), '.arclint'
    cp path.join(rootDir, 'arc-N1', 'arclib'), 'arclib'

  copySourceExtensions = ->
    cp path.join(rootDir, 'src'), 'src'

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
