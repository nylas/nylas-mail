# Swap out Node's native Promise for Bluebird, which allows us to
# do fancy things like handle exceptions inside promise blocks
global.Promise = require 'bluebird'

# Like sands through the hourglass, so are the days of our lives.
require './window'

{windowName, windowPackages} = JSON.parse(decodeURIComponent(location.search.substr(14)))

Atom = require './atom'
window.atom = Atom.loadOrCreate(windowName)
atom.initialize()
atom.startSecondaryWindow(windowPackages)

# Workaround for focus getting cleared upon window creation
windowFocused = ->
  window.removeEventListener('focus', windowFocused)
  setTimeout (-> document.querySelector('body').focus()), 0
window.addEventListener('focus', windowFocused)
