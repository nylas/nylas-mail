Reflux = require 'reflux'

Actions = [
  'focusAccounts'
]

for idx in Actions
  Actions[idx] = Reflux.createAction(Actions[idx])
  Actions[idx].sync = true

module.exports = Actions
