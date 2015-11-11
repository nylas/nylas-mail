path = require('path')
fs = require('fs-plus')
ipc = require('ipc')

require('module').globalPaths.push(path.resolve('exports'))

# Swap out Node's native Promise for Bluebird, which allows us to
# do fancy things like handle exceptions inside promise blocks
global.Promise = require 'bluebird'
global.NylasEnv =
  commands:
    add: ->
    remove: ->
  config:
    get: -> null
    set: ->
    onDidChange: ->
  onBeforeUnload: ->
  getWindowLoadTime: -> 0
  getConfigDirPath: ->
    @configDirPath ?= fs.absolute('~/.nylas')
  getLoadSettings: ->
    @loadSettings ?= JSON.parse(decodeURIComponent(location.search.substr(14)))
  inSpecMode: ->
    false

  isMainWindow: ->
    false

# Like sands through the hourglass, so are the days of our lives.
require './window'
prefs = require '../internal_packages/preferences/lib/main'
prefs.activate()

ipc.on 'command', (command, args) ->
  if command is 'window:toggle-dev-tools'
    ipc.send('call-window-method', 'toggleDevTools')
