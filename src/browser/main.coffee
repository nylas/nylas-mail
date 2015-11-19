global.shellStartTime = Date.now()

process.on 'uncaughtException', (error={}) ->
  console.log(error.message) if error.message?
  console.log(error.stack) if error.stack?

app = require 'app'
fs = require 'fs-plus'
path = require 'path'
optimist = require 'optimist'

start = ->
  args = parseCommandLine()
  global.errorLogger = setupErrorLogger(args)
  setupNylasHome(args)
  setupCompileCache()
  return if handleStartupEventWithSquirrel()

  # This prevents Win10 from showing dupe items in the taskbar
  app.setAppUserModelId('com.squirrel.nylas.nylas')

  addPathToOpen = (event, pathToOpen) ->
    event.preventDefault()
    args.pathsToOpen.push(pathToOpen)

  addUrlToOpen = (event, urlToOpen) ->
    event.preventDefault()
    args.urlsToOpen.push(urlToOpen)

  app.on 'open-file', addPathToOpen
  app.on 'open-url', addUrlToOpen

  app.on 'will-finish-launching', ->
    setupCrashReporter()

  app.on 'ready', ->
    app.removeListener 'open-file', addPathToOpen
    app.removeListener 'open-url', addUrlToOpen

    Application = require path.join(args.resourcePath, 'src', 'browser', 'application')
    Application.open(args)

    console.log("App load time: #{Date.now() - global.shellStartTime}ms") unless args.test

setupNylasHome = ->
  return if process.env.NYLAS_HOME
  atomHome = path.join(app.getHomeDir(), '.nylas')
  process.env.NYLAS_HOME = atomHome

normalizeDriveLetterName = (filePath) ->
  if process.platform is 'win32'
    filePath.replace /^([a-z]):/, ([driveLetter]) -> driveLetter.toUpperCase() + ":"
  else
    filePath

handleStartupEventWithSquirrel = ->
  return false unless process.platform is 'win32'
  SquirrelUpdate = require './squirrel-update'
  squirrelCommand = process.argv[1]
  SquirrelUpdate.handleStartupEvent(app, squirrelCommand)

setupCompileCache = ->
  compileCache = require('../compile-cache')
  compileCache.setHomeDirectory(process.env.NYLAS_HOME)

setupErrorLogger = (args={}) ->
  ErrorLogger = require '../error-logger'
  return new ErrorLogger
    inSpecMode: args.test
    inDevMode: args.devMode
    resourcePath: args.resourcePath

setupCrashReporter = ->
  # In the future, we may want to collect actual native crash reports,
  # but for now let's not send them to GitHub
  # crashReporter.start(productName: "N1", companyName: "Nylas")

parseCommandLine = ->
  version = app.getVersion()
  options = optimist(process.argv[1..])
  options.usage """
    N1 v#{version}

    Usage: n1 [options] [path ...]

    One or more paths to files or folders to open may be specified.

    File paths will open in the current window.

    Folder paths will open in an existing window if that folder has already been
    opened or a new window if it hasn't.

    Environment Variables:
    N1_PATH  The path from which N1 loads source code in dev mode.
             Defaults to `cwd`.
  """
  options.alias('d', 'dev').boolean('d').describe('d', 'Run in development mode.')
  options.alias('f', 'foreground').boolean('f').describe('f', 'Keep the browser process in the foreground.')
  options.alias('h', 'help').boolean('h').describe('h', 'Print this usage message.')
  options.alias('l', 'log-file').string('l').describe('l', 'Log all output to file.')
  options.alias('n', 'new-window').boolean('n').describe('n', 'Open a new window.')
  options.alias('r', 'resource-path').string('r').describe('r', 'Set the path to the N1 source directory and enable dev-mode.')
  options.alias('s', 'spec-directory').string('s').describe('s', 'Set the directory from which to run package specs (default: N1\'s spec directory).')
  options.boolean('safe').describe('safe', 'Do not load packages from ~/.nylas/packages or ~/.nylas/dev/packages.')
  options.alias('t', 'test').boolean('t').describe('t', 'Run the specified specs and exit with error code on failures.')
  options.alias('v', 'version').boolean('v').describe('v', 'Print the version.')
  options.alias('w', 'wait').boolean('w').describe('w', 'Wait for window to be closed before returning.')
  args = options.argv

  if args.help
    process.stdout.write(options.help())
    process.exit(0)

  if args.version
    process.stdout.write("#{version}\n")
    process.exit(0)

  executedFrom = args['executed-from']?.toString() ? process.cwd()
  devMode = args['dev']
  safeMode = args['safe']
  pathsToOpen = args._
  pathsToOpen = [executedFrom] if executedFrom and pathsToOpen.length is 0
  urlsToOpen = []
  test = args['test']
  specDirectory = args['spec-directory']
  newWindow = args['new-window']
  pidToKillWhenClosed = args['pid'] if args['wait']
  logFile = args['log-file']
  specFilePattern = args['file-pattern']
  devResourcePath = process.env.N1_PATH ? process.cwd()

  if args['resource-path']
    devMode = true
    resourcePath = args['resource-path']
  else
    specsOnCommandLine = true
    # Set resourcePath based on the specDirectory if running specs on N1 core
    if specDirectory?
      packageDirectoryPath = path.resolve(specDirectory, '..')
      packageManifestPath = path.join(packageDirectoryPath, 'package.json')
      if fs.statSyncNoException(packageManifestPath)
        try
          packageManifest = JSON.parse(fs.readFileSync(packageManifestPath))
          resourcePath = packageDirectoryPath if packageManifest.name is 'edgehill'
    else
      # EDGEHILL_CORE: if test is given a name, assume that's the package we
      # want to test.
      if test and toString.call(test) is "[object String]"
        if test is "core"
          specDirectory = path.join(devResourcePath, "spec")
        else if test is "window"
          specDirectory = path.join(devResourcePath, "spec")
          specsOnCommandLine = false
        else
          specDirectory = path.resolve(path.join(devResourcePath, "internal_packages", test))

  devMode = true if test
  resourcePath ?= devResourcePath if devMode

  unless fs.statSyncNoException(resourcePath)
    resourcePath = path.dirname(path.dirname(__dirname))

  # On Yosemite the $PATH is not inherited by the "open" command, so we have to
  # explicitly pass it by command line, see http://git.io/YC8_Ew.
  process.env.PATH = args['path-environment'] if args['path-environment']

  resourcePath = normalizeDriveLetterName(resourcePath)
  devResourcePath = normalizeDriveLetterName(devResourcePath)

  {resourcePath, pathsToOpen, urlsToOpen, executedFrom, test, version, pidToKillWhenClosed, devMode, safeMode, newWindow, specDirectory, specsOnCommandLine, logFile, specFilePattern}

start()
