Reflux = require 'reflux'

Actions = [
  'temporarilyEnableImages'
  'permanentlyEnableImages'
]

for key in Actions
  Actions[key] = Reflux.createAction(name)
  Actions[key].sync = true

module.exports = Actions
