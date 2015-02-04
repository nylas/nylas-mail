Reflux = require 'reflux'

actions = [
  "setEnvironment",
  "createAccount",
  "signIn",
  "authErrorOccurred",
  "startConnect",
  "finishedConnect",
  "moveToPreviousPage",
  "moveToPage"
]

module.exports =
Actions = Reflux.createActions(actions)
