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

# Get the user's PATH environment variable registry value.
getPath = (callback) ->
  spawnReg ['query', environmentKeyPath, '/v', 'Path'], (error, stdout) ->
    if error?
      if error.code is 1
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
      callback(null, pathEnv)
    else
      callback(new Error('Registry query for PATH failed'))

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
        app.quit()
      true
    when '--squirrel-updated'
      updateShortcuts ->
        app.quit()
      true
    when '--squirrel-uninstall'
      removeShortcuts ->
        app.quit()
      true
    when '--squirrel-obsolete'
      app.quit()
      true
    else
      false
