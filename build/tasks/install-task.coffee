path = require 'path'
_ = require 'underscore'
fs = require 'fs-plus'
runas = null
temp = require 'temp'

module.exports = (grunt) ->
  {cp, mkdir, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'install', 'Install the built application', ->
    appFileName = grunt.config.get('nylasGruntConfig.appFileName')
    installDir = grunt.config.get('nylasGruntConfig.installDir')
    shellAppDir = grunt.config.get('nylasGruntConfig.shellAppDir')

    if process.platform is 'win32'
      runas ?= require 'runas'
      copyFolder = path.resolve 'script', 'copy-folder.cmd'
      if runas('cmd', ['/c', copyFolder, shellAppDir, installDir], admin: true) isnt 0
        grunt.log.error("Failed to copy #{shellAppDir} to #{installDir}")

      createShortcut = path.resolve('script', 'create-shortcut.cmd')
      shortcutIconPath = path.resolve('script', 'build', 'resources', 'win', 'nylas.ico')
      runas('cmd', ['/c', createShortcut, path.join(installDir, 'nylas.exe'), 'Nylas', shortcutIconPath])

    else if process.platform is 'darwin'
      rm installDir
      mkdir path.dirname(installDir)

      tempFolder = temp.path()
      mkdir tempFolder
      cp shellAppDir, tempFolder
      fs.renameSync(tempFolder, installDir)

    else
      linuxBinDir = path.join(installDir, 'bin')
      linuxShareDir = path.join(installDir, 'share', 'nylas')
      iconName = path.join(linuxShareDir, 'resources', 'app', 'nylas.png')

      mkdir linuxBinDir
      cp path.join('build', 'resources', 'nylas.sh'), path.join(linuxBinDir, 'nylas')
      rm linuxShareDir
      mkdir path.dirname(linuxShareDir)
      cp shellAppDir, linuxShareDir

      # Create nylas.desktop if installation not in temporary folder
      tmpDir = if process.env.TMPDIR? then process.env.TMPDIR else '/tmp'
      if installDir.indexOf(tmpDir) isnt 0
        desktopFile = path.join('build', 'resources', 'linux', 'nylas.desktop.in')
        desktopInstallFile = path.join(installDir, 'share', 'applications', 'nylas.desktop')

        {description} = grunt.file.readJSON('package.json')
        iconName = path.join(linuxShareDir, 'resources', 'app', 'nylas.png')
        installDir = path.join(installDir, '.') # To prevent "Exec=/usr/local//share/nylas/nylas"
        template = _.template(fs.readFileSync(desktopFile, 'utf8'))
        filled = template({appFileName, description, installDir, iconName, linuxShareDir})

        grunt.file.write(desktopInstallFile, filled)

      fs.chmodSync(path.join(linuxShareDir, 'nylas'), "755")

    grunt.log.ok("Installed Nylas into #{installDir}")
