ChildProcess = require 'child_process'
fs = require 'fs-plus'
path = require 'path'

appFolder = path.resolve(process.execPath, '..')
rootN1Folder = path.resolve(appFolder, '..')
binFolder = path.join(rootN1Folder, 'bin')
updateDotExe = path.join(rootN1Folder, 'Update.exe')
exeName = path.basename(process.execPath)

if process.env.SystemRoot
  system32Path = path.join(process.env.SystemRoot, 'System32')
  regPath = path.join(system32Path, 'reg.exe')
  setxPath = path.join(system32Path, 'setx.exe')
else
  regPath = 'reg.exe'
  setxPath = 'setx.exe'

# Registry keys used for context menu
environmentKeyPath = 'HKCU\\Environment'

# Spawn a command and invoke the callback when it completes with an error
# and the output from standard out.
spawn = (command, args, callback) ->
  stdout = ''

  try
    spawnedProcess = ChildProcess.spawn(command, args)
  catch error
    # Spawn can throw an error
    process.nextTick -> callback?(error, stdout)
    return

  spawnedProcess.stdout.on 'data', (data) -> stdout += data

  error = null
  spawnedProcess.on 'error', (processError) -> error ?= processError
  spawnedProcess.on 'close', (code, signal) ->
    error ?= new Error("Command failed: #{signal ? code}") if code isnt 0
    error?.code ?= code
    error?.stdout ?= stdout
    callback?(error, stdout)

# Spawn reg.exe and callback when it completes
spawnReg = (args, callback) ->
  spawn(regPath, args, callback)

# Spawn setx.exe and callback when it completes
spawnSetx = (args, callback) ->
  spawn(setxPath, args, callback)

# Spawn the Update.exe with the given arguments and invoke the callback when
# the command completes.
spawnUpdate = (args, callback) ->
  spawn(updateDotExe, args, callback)

isAscii = (text) ->
  index = 0
  while index < text.length
    return false if text.charCodeAt(index) > 127
    index++
  true

# Get the user's PATH environment variable registry value.
getPath = (callback) ->
  spawnReg ['query', environmentKeyPath, '/v', 'Path'], (error, stdout) ->
    if error?
      if error.code is 1
        # FIXME Don't overwrite path when reading value is disabled
        # https://github.com/atom/atom/issues/5092
        if stdout.indexOf('ERROR: Registry editing has been disabled by your administrator.') isnt -1
          return callback(error)

        # The query failed so the Path does not exist yet in the registry
        return callback(null, '')
      else
        return callback(error)

    # Registry query output is in the form:
    #
    # HKEY_CURRENT_USER\Environment
    #     Path    REG_SZ    C:\a\folder\on\the\path;C\another\folder
    #

    lines = stdout.split(/[\r\n]+/).filter (line) -> line
    segments = lines[lines.length - 1]?.split('    ')
    if segments[1] is 'Path' and segments.length >= 3
      pathEnv = segments?[3..].join('    ')
      if isAscii(pathEnv)
        callback(null, pathEnv)
      else
        # FIXME Don't corrupt non-ASCII PATH values
        # https://github.com/atom/atom/issues/5063
        callback(new Error('PATH contains non-ASCII values'))
    else
      callback(new Error('Registry query for PATH failed'))

# Add N1 to the PATH
#
# This is done by adding .cmd shims to the root bin folder in the N1
# install directory that point to the newly installed versions inside
# the versioned app directories.
addCommandsToPath = (callback) ->
  installCommands = (callback) ->
    nylasCommandPath = path.join(binFolder, 'N1.cmd')
    relativeN1Path = path.relative(binFolder, path.join(appFolder, 'resources', 'cli', 'N1.cmd'))
    nylasCommand = "@echo off\r\n\"%~dp0\\#{relativeN1Path}\" %*"

    nylasShCommandPath = path.join(binFolder, 'N1')
    relativeN1ShPath = path.relative(binFolder, path.join(appFolder, 'resources', 'cli', 'N1.sh'))
    nylasShCommand = "#!/bin/sh\r\n\"$(dirname \"$0\")/#{relativeN1ShPath.replace(/\\/g, '/')}\" \"$@\""

    fs.writeFile nylasCommandPath, nylasCommand, ->
      fs.writeFile nylasShCommandPath, nylasShCommand, ->
        callback()

  addBinToPath = (pathSegments, callback) ->
    pathSegments.push(binFolder)
    newPathEnv = pathSegments.join(';')
    spawnSetx(['Path', newPathEnv], callback)

  installCommands (error) ->
    return callback(error) if error?

    getPath (error, pathEnv) ->
      return callback(error) if error?

      pathSegments = pathEnv.split(/;+/).filter (pathSegment) -> pathSegment
      if pathSegments.indexOf(binFolder) is -1
        addBinToPath(pathSegments, callback)
      else
        callback()

# Remove N1 from the PATH
removeCommandsFromPath = (callback) ->
  getPath (error, pathEnv) ->
    return callback(error) if error?

    pathSegments = pathEnv.split(/;+/).filter (pathSegment) ->
      pathSegment and pathSegment isnt binFolder
    newPathEnv = pathSegments.join(';')

    if pathEnv isnt newPathEnv
      spawnSetx(['Path', newPathEnv], callback)
    else
      callback()

# Create a desktop and start menu shortcut by using the command line API
# provided by Squirrel's Update.exe
createShortcuts = (callback) ->
  spawnUpdate(['--createShortcut', exeName], callback)

# Update the desktop and start menu shortcuts by using the command line API
# provided by Squirrel's Update.exe
updateShortcuts = (callback) ->
  if homeDirectory = fs.getHomeDirectory()
    desktopShortcutPath = path.join(homeDirectory, 'Desktop', 'N1.lnk')
    # Check if the desktop shortcut has been previously deleted and
    # and keep it deleted if it was
    fs.exists desktopShortcutPath, (desktopShortcutExists) ->
      createShortcuts ->
        if desktopShortcutExists
          callback()
        else
          # Remove the unwanted desktop shortcut that was recreated
          fs.unlink(desktopShortcutPath, callback)
  else
    createShortcuts(callback)

# Remove the desktop and start menu shortcuts by using the command line API
# provided by Squirrel's Update.exe
removeShortcuts = (callback) ->
  spawnUpdate(['--removeShortcut', exeName], callback)

exports.spawn = spawnUpdate

# Is the Update.exe installed with N1?
exports.existsSync = ->
  fs.existsSync(updateDotExe)

# Restart N1 using the version pointed to by the N1.cmd shim
exports.restartN1 = (app) ->
  if projectPath = global.application?.lastFocusedWindow?.projectPath
    args = [projectPath]
  app.once 'will-quit', -> spawn(path.join(binFolder, 'N1.cmd'), args)
  app.quit()

# Handle squirrel events denoted by --squirrel-* command line arguments.
exports.handleStartupEvent = (app, squirrelCommand) ->
  switch squirrelCommand
    when '--squirrel-install'
      createShortcuts ->
        addCommandsToPath (error) ->
          console.error(error) if error
          app.quit()
      true
    when '--squirrel-updated'
      updateShortcuts ->
        addCommandsToPath (error) ->
          console.error(error) if error
          app.quit()
      true
    when '--squirrel-uninstall'
      removeShortcuts ->
        removeCommandsFromPath (error) ->
          console.error(error) if error
          app.quit()
      true
    when '--squirrel-obsolete'
      app.quit()
      true
    else
      false
