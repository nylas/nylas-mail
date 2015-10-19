fs = require 'fs'
path = require 'path'
_ = require 'underscore'

module.exports = (grunt) ->
  {spawn, rm, mkdir} = require('./task-helpers')(grunt)

  fillTemplate = (filePath, data) ->
    template = _.template(String(fs.readFileSync("#{filePath}.in")))
    filled = template(data)

    outputPath = path.join(grunt.config.get('nylas.buildDir'), path.basename(filePath))
    grunt.file.write(outputPath, filled)
    outputPath

  grunt.registerTask 'mkrpm', 'Create rpm package', ->
    done = @async()

    if process.arch is 'ia32'
      arch = 'i386'
    else if process.arch is 'x64'
      arch = 'amd64'
    else
      return done("Unsupported arch #{process.arch}")

    {name, version, description} = grunt.file.readJSON('package.json')
    buildDir = grunt.config.get('nylas.buildDir')

    rpmDir = path.join(buildDir, 'rpm')
    rm rpmDir
    mkdir rpmDir

    installDir = grunt.config.get('nylas.installDir')
    shareDir = path.join(installDir, 'share', 'nylas')
    iconName = path.join(shareDir, 'resources', 'app', 'resources', 'nylas.png')

    data = {name, version, description, installDir, iconName}
    specFilePath = fillTemplate(path.join('build', 'resources', 'linux', 'redhat', 'nylas.spec'), data)
    desktopFilePath = fillTemplate(path.join('build', 'resources', 'linux', 'nylas.desktop'), data)

    cmd = path.join('script', 'mkrpm')
    args = [specFilePath, desktopFilePath, buildDir]
    spawn {cmd, args}, (error) ->
      if error?
        done(error)
      else
        grunt.log.ok "Created rpm package in #{rpmDir}"
        done()
