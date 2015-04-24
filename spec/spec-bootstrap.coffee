# Start the crash reporter before anything else.
require('crash-reporter').start(productName: 'Atom', companyName: 'GitHub')

path = require 'path'
fs = require 'fs-plus'

# Swap out Node's native Promise for Bluebird, which allows us to
# do fancy things like handle exceptions inside promise blocks
global.Promise = require 'bluebird'

try
  require '../src/window'
  Atom = require '../src/atom'
  Atom.configDirPath = fs.absolute('~/.inbox-spec')
  window.atom = Atom.loadOrCreate()

  # Show window synchronously so a focusout doesn't fire on input elements
  # that are focused in the very first spec run.
  atom.getCurrentWindow().show() unless atom.getLoadSettings().exitWhenDone

  {runSpecSuite} = require './jasmine-helper'

  # Add 'exports' to module search path.
  exportsPath = path.join(atom.getLoadSettings().resourcePath, 'exports')
  require('module').globalPaths.push(exportsPath)
  # Still set NODE_PATH since tasks may need it.
  process.env.NODE_PATH = exportsPath

  document.title = "Spec Suite"
  runSpecSuite './spec-suite', atom.getLoadSettings().logFile
catch error
  if atom?.getLoadSettings().exitWhenDone
    console.error(error.stack ? error)
    atom.exit(1)
  else
    throw error
