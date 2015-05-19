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

      createShortcut = path.resolve 'script', 'create-shortcut.cmd'
      runas('cmd', ['/c', createShortcut, path.join(installDir, 'edgehill.exe'), 'Edgehill'])
    else if process.platform is 'darwin'
      rm installDir
      mkdir path.dirname(installDir)

      tempFolder = temp.path()
      mkdir tempFolder
      cp shellAppDir, tempFolder
      fs.renameSync(tempFolder, installDir)
    else
      binDir = path.join(installDir, 'bin')
      shareDir = path.join(installDir, 'share', 'edgehill')

      iconName = path.join(shareDir,'resources', 'app', 'resources', 'edgehill.png')

      mkdir binDir
      # Note that `atom.sh` can't be renamed `edgehill.sh` because `apm`
      # is currently hard-coded to call `atom.sh`
      cp 'atom.sh', path.join(binDir, 'edgehill')
      rm shareDir
      mkdir path.dirname(shareDir)
      cp shellAppDir, shareDir

      # Create edgehill.desktop if installation not in temporary folder
      tmpDir = if process.env.TMPDIR? then process.env.TMPDIR else '/tmp'
      if installDir.indexOf(tmpDir) isnt 0
        desktopFile = path.join('resources', 'linux', 'edgehill.desktop.in')
        desktopInstallFile = path.join(installDir, 'share', 'applications', 'edgehill.desktop')

        {description} = grunt.file.readJSON('package.json')
        iconName = path.join(shareDir, 'resources', 'app', 'resources', 'edgehill.png')
        installDir = path.join(installDir, '.') # To prevent "Exec=/usr/local//share/edgehill/edgehill"
        template = _.template(String(fs.readFileSync(desktopFile)))
        filled = template({description, installDir, iconName})

        grunt.file.write(desktopInstallFile, filled)

      # Create relative symbol link for apm.
      process.chdir(binDir)
      rm('apm')
      fs.symlinkSync(path.join('..', 'share', 'edgehill', 'resources', 'app', 'apm', 'node_modules', '.bin', 'apm'), 'apm')

      fs.chmodSync(path.join(shareDir, 'edgehill'), "755")

    grunt.log.ok("Installed Edgehill into #{installDir}")
