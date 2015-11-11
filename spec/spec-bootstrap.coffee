# Start the crash reporter before anything else.
require('crash-reporter').start(productName: 'N1', companyName: 'Nylas')


path = require 'path'
fs = require 'fs-plus'

# Swap out Node's native Promise for Bluebird, which allows us to
# do fancy things like handle exceptions inside promise blocks
global.Promise = require 'bluebird'

try
  require '../src/window'
  NylasEnvConstructor = require '../src/nylas-env'
  NylasEnvConstructor.configDirPath = fs.absolute('~/.nylas-spec')
  window.NylasEnv = NylasEnvConstructor.loadOrCreate()
  global.Promise.longStackTraces() if NylasEnv.inDevMode()

  # Show window synchronously so a focusout doesn't fire on input elements
  # that are focused in the very first spec run.
  NylasEnv.getCurrentWindow().show() unless NylasEnv.getLoadSettings().exitWhenDone

  {runSpecSuite} = require './jasmine-helper'

  # Add 'src/global' to module search path.
  globalPath = path.join(NylasEnv.getLoadSettings().resourcePath, 'src', 'global')
  require('module').globalPaths.push(globalPath)
  # Still set NODE_PATH since tasks may need it.
  process.env.NODE_PATH = globalPath

  document.title = "Spec Suite"
  document.getElementById("application-loading-cover").remove()

  runSpecSuite './spec-suite', NylasEnv.getLoadSettings().logFile
catch error
  if NylasEnv?.getLoadSettings().exitWhenDone
    console.error(error.stack ? error)
    NylasEnv.exit(1)
  else
    throw error
