# Swap out Node's native Promise for Bluebird, which allows us to
# do fancy things like handle exceptions inside promise blocks
global.Promise = require 'bluebird'

# Like sands through the hourglass, so are the days of our lives.
require './window'

NylasEnvConstructor = require './nylas-env'
window.NylasEnv = window.atom = NylasEnvConstructor.loadOrCreate()
global.Promise.longStackTraces() if NylasEnv.inDevMode()
NylasEnv.initialize()
NylasEnv.startRootWindow()


# Workaround for focus getting cleared upon window creation
windowFocused = ->
  window.removeEventListener('focus', windowFocused)
  setTimeout (-> document.getElementById('sheet-container').focus()), 0
window.addEventListener('focus', windowFocused)
