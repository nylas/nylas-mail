path = require 'path'
_ = require 'underscore'
fs = require 'fs-plus'
runas = null
temp = require 'temp'

module.exports = (grunt) ->
  {cp, mkdir, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'install', 'Install the built application', ->
    installDir = grunt.config.get('atom.installDir')
    shellAppDir = grunt.config.get('atom.shellAppDir')

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
      binDir = path.join(installDir, 'bin')
      shareDir = path.join(installDir, 'share', 'nylas')
      iconName = path.join(shareDir, 'resources', 'app', 'resources', 'nylas.png')

      mkdir binDir
      # Note that `atom.sh` can't be renamed `nylas.sh` because `apm`
      # is currently hard-coded to call `atom.sh`
      cp 'atom.sh', path.join(binDir, 'nylas')
      rm shareDir
      mkdir path.dirname(shareDir)
      cp shellAppDir, shareDir

      # Create nylas.desktop if installation not in temporary folder
      tmpDir = if process.env.TMPDIR? then process.env.TMPDIR else '/tmp'
      if installDir.indexOf(tmpDir) isnt 0
        desktopFile = path.join('build', 'resources', 'linux', 'nylas.desktop.in')
        desktopInstallFile = path.join(installDir, 'share', 'applications', 'nylas.desktop')

        {description} = grunt.file.readJSON('package.json')
        iconName = path.join(shareDir, 'resources', 'app', 'resources', 'nylas.png')
        installDir = path.join(installDir, '.') # To prevent "Exec=/usr/local//share/nylas/nylas"
        template = _.template(String(fs.readFileSync(desktopFile)))
        filled = template({description, installDir, iconName})

        grunt.file.write(desktopInstallFile, filled)

      # Create relative symbol link for apm.
      process.chdir(binDir)
      rm('apm')
      fs.symlinkSync(path.join('..', 'share', 'nylas', 'resources', 'app', 'apm', 'node_modules', '.bin', 'apm'), 'apm')

      fs.chmodSync(path.join(shareDir, 'nylas'), "755")

    grunt.log.ok("Installed Nylas into #{installDir}")
