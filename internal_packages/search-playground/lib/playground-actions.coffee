Reflux = require 'reflux'

Actions = Reflux.createActions([
  "setRankNext",
  "clearRanks",
  "submitRanks"
])

for key, action of Actions
  action.sync = true

module.exports = Actions