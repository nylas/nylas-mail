Reflux = require 'reflux'

SearchActions = Reflux.createActions [
  "querySubmitted"
  "queryChanged"
  "searchBlurred"
]

for key, action of SearchActions
  action.sync = true

module.exports = SearchActions
