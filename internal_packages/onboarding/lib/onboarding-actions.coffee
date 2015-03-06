Reflux = require 'reflux'

actions = [
  "setEnvironment",
  "authErrorOccurred",
  "startConnect",
  "finishedConnect",
  "moveToPreviousPage",
  "moveToPage"
]

module.exports =
Actions = Reflux.createActions(actions)
