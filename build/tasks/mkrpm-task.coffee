fs = require 'fs'
path = require 'path'
_ = require 'underscore'

module.exports = (grunt) ->
  {spawn, rm, mkdir, fillTemplate} = require('./task-helpers')(grunt)

  grunt.registerTask 'mkrpm', 'Create rpm package', ->
    done = @async()

    iconName = 'nylas'

    # Default: nylas
    appFileName = grunt.config.get('nylasGruntConfig.appFileName')

    # Default: Nylas
    appName = grunt.config.get('nylasGruntConfig.appName')

    # Default: /tmp/nylas-build
    buildDir = grunt.config.get('nylasGruntConfig.buildDir')

    # Default: /tmp/nylas-build/nylas
    contentsDir = grunt.config.get('nylasGruntConfig.contentsDir')

    # Default: /usr/local/bin
    linuxBinDir = grunt.config.get('nylasGruntConfig.linuxBinDir')

    # Default: /usr/local/share/nylas
    linuxShareDir = grunt.config.get('nylasGruntConfig.linuxShareDir')

    if process.arch is 'ia32'
      arch = 'i386'
    else if process.arch is 'x64'
      arch = 'amd64'
    else
      return done("Unsupported arch #{process.arch}")

    {name, version, description} = grunt.file.readJSON('package.json')

    rpmDir = path.join(buildDir, 'rpm')
    rm rpmDir
    mkdir rpmDir

    templateData = {name, version, buildDir, description, iconName, linuxBinDir, linuxShareDir, contentsDir, appName, appFileName}

    linuxResourcesPath = path.join('build', 'resources', 'linux')
    # This populates nylas.spec
    specInFilePath = path.join(linuxResourcesPath, 'redhat', 'nylas.spec.in')
    specOutFilePath = path.join(buildDir, 'nylas.spec')
    fillTemplate(specInFilePath, specOutFilePath, templateData)

    # This populates nylas.desktop
    desktopInFilePath = path.join(linuxResourcesPath, 'nylas.desktop.in')
    desktopOutFilePath = path.join(buildDir, 'nylas.desktop')
    fillTemplate(desktopInFilePath, desktopOutFilePath, templateData)

    cmd = path.join('script', 'mkrpm')
    args = [specOutFilePath, desktopOutFilePath, buildDir, contentsDir, appFileName]
    spawn {cmd, args}, (error) ->
      if error?
        done(error)
      else
        grunt.log.ok "Created rpm package in #{rpmDir}"
        done()
