# Effectively all secondary windows are empty hot windows. We spawn the
# window and pre-load all of the basic javascript libraries (which takes a
# full second or so).
#
# Eventually when `WindowManager::newWindow` gets called, instead of
# actually spawning a new window, we'll call
# `NylasWindow::setLoadSettings` on the window instead. This will replace
# the window options, adjust params as necessary, and then re-load the
# plugins. Once `NylasWindow::setLoadSettings` fires, the main NylasEnv in
# the window will be notified via the `load-settings-changed` config

# Swap out Node's native Promise for Bluebird, which allows us to
# do fancy things like handle exceptions inside promise blocks
global.Promise = require 'bluebird'
Promise.setScheduler(global.setImmediate)

require './window'

NylasEnvConstructor = require './nylas-env'
window.NylasEnv = window.atom = NylasEnvConstructor.loadOrCreate()

global.Promise.longStackTraces() if NylasEnv.inDevMode()

NylasEnv.initialize()
NylasEnv.startSecondaryWindow()

# Workaround for focus getting cleared upon window creation
windowFocused = ->
  window.removeEventListener('focus', windowFocused)
  setTimeout (-> document.querySelector('body').focus()), 0
window.addEventListener('focus', windowFocused)
