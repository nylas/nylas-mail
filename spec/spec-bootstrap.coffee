# Start the crash reporter before anything else.
require('crash-reporter').start(productName: 'N1', companyName: 'Nylas')


path = require 'path'
fs = require 'fs-plus'

# Swap out Node's native Promise for Bluebird, which allows us to
# do fancy things like handle exceptions inside promise blocks
global.Promise = require 'bluebird'

try
  require '../src/window'
  Atom = require '../src/atom'
  Atom.configDirPath = fs.absolute('~/.nylas-spec')
  window.atom = Atom.loadOrCreate()
  global.Promise.longStackTraces() if atom.inDevMode()

  # Show window synchronously so a focusout doesn't fire on input elements
  # that are focused in the very first spec run.
  atom.getCurrentWindow().show() unless atom.getLoadSettings().exitWhenDone

  {runSpecSuite} = require './jasmine-helper'

  # Add 'src/global' to module search path.
  globalPath = path.join(atom.getLoadSettings().resourcePath, 'src', 'global')
  require('module').globalPaths.push(globalPath)
  # Still set NODE_PATH since tasks may need it.
  process.env.NODE_PATH = globalPath

  document.title = "Spec Suite"
  document.getElementById("application-loading-cover").remove()

  runSpecSuite './spec-suite', atom.getLoadSettings().logFile
catch error
  if atom?.getLoadSettings().exitWhenDone
    console.error(error.stack ? error)
    atom.exit(1)
  else
    throw error
