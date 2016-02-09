global.shellStartTime = Date.now()

{app} = require 'electron'
fs = require 'fs-plus'
path = require 'path'
mkdirp = require 'mkdirp'

start = ->
  args = parseCommandLine()
  global.errorLogger = setupErrorLogger(args)
  configDirPath = setupConfigDir(args)
  args.configDirPath = configDirPath
  setupCompileCache(configDirPath)
  return if handleStartupEventWithSquirrel()

  # This prevents Win10 from showing dupe items in the taskbar
  app.setAppUserModelId('com.squirrel.nylas.nylas')

  addUrlToOpen = (event, urlToOpen) ->
    event.preventDefault()
    args.urlsToOpen.push(urlToOpen)

  app.on 'open-url', addUrlToOpen

  app.on 'ready', ->
    app.removeListener 'open-url', addUrlToOpen

    Application = require path.join(args.resourcePath, 'src', 'browser', 'application')
    Application.open(args)

    console.log("App load time: #{Date.now() - global.shellStartTime}ms") unless args.specMode

setupConfigDir = (args) ->
  # https://github.com/atom/atom/issues/8281
  if args.specMode
    defaultConfigDir = path.join(app.getPath('home'), '.nylas-spec')
  else
    defaultConfigDir = path.join(app.getPath('home'), '.nylas')

  configDirPath = args.configDirPath ?
                  process.env.NYLAS_HOME ?
                  defaultConfigDir

  mkdirp.sync(configDirPath)

  process.env.NYLAS_HOME = configDirPath

  return configDirPath

handleStartupEventWithSquirrel = ->
  return false unless process.platform is 'win32'
  WindowsUpdater = require './windows-updater'
  squirrelCommand = process.argv[1]
  WindowsUpdater.handleStartupEvent(app, squirrelCommand)

setupCompileCache = (configDirPath) ->
  compileCache = require('../compile-cache')
  compileCache.setHomeDirectory(configDirPath)

setupErrorLogger = (args={}) ->
  ErrorLogger = require '../error-logger'
  errorLogger = new ErrorLogger
    inSpecMode: args.specMode
    inDevMode: args.devMode
    resourcePath: args.resourcePath

  process.on 'uncaughtException', errorLogger.reportError
  process.on 'unhandledRejection', errorLogger.reportError
  return errorLogger

declareOptions = (argv) ->
  optimist = require 'optimist'
  options = optimist(argv)
  options.usage """
    Nylas N1 v#{app.getVersion()}

    Usage: n1 [options]

    Run N1: The open source extensible email client

    `n1 --dev` to start the client in dev mode.

    `n1 --test` to run unit tests.
  """
  options.alias('d', 'dev').boolean('d')
    .describe('d', 'Run in development mode.')

  options.alias('t', 'test').boolean('t')
    .describe('t', 'Run the specified specs and exit with error code on failures.')

  options.boolean('safe')
    .describe('safe', 'Do not load packages from ~/.nylas/packages or ~/.nylas/dev/packages.')

  options.alias('h', 'help').boolean('h')
    .describe('h', 'Print this usage message.')

  options.alias('l', 'log-file').string('l')
    .describe('l', 'Log all test output to file.')

  options.alias('c', 'config-dir-path').string('c')
    .describe('c', 'Override the path to the N1 configuration directory')

  options.alias('s', 'spec-directory').string('s')
    .describe('s', 'Override the directory from which to run package specs')

  options.alias('f', 'spec-file-pattern').string('f')
    .describe('f', 'Override the default file regex to determine which tests should run (defaults to "-spec\.(coffee|js|jsx|cjsx|es6|es)$" )')

  options.alias('v', 'version').boolean('v')
    .describe('v', 'Print the version.')

  options.alias('b', 'background').boolean('b')
    .describe('b', 'Start N1 in the background')

  return options

parseCommandLine = ->
  version = app.getVersion()
  options = declareOptions(process.argv[1..])
  args = options.argv

  if args.help
    process.stdout.write(options.help())
    process.exit(0)

  if args.version
    process.stdout.write("#{version}\n")
    process.exit(0)

  devMode = args['dev'] || args['test']
  logFile = args['log-file']
  specMode = args['test']
  safeMode = args['safe']
  background = args['background']
  configDirPath = args['config-dir-path']
  specDirectory = args['spec-directory']
  specFilePattern = args['spec-file-pattern']
  showSpecsInWindow = specMode is "window"

  resourcePath = path.resolve(args['resource-path'] ?
                              path.dirname(path.dirname(__dirname)))

  urlsToOpen = []

  # On Yosemite the $PATH is not inherited by the "open" command, so we
  # have to explicitly pass it by command line, see http://git.io/YC8_Ew.
  process.env.PATH = args['path-environment'] if args['path-environment']

  return {version, devMode, background, logFile, specMode, safeMode, configDirPath, specDirectory, specFilePattern, showSpecsInWindow, resourcePath, urlsToOpen}

start()
