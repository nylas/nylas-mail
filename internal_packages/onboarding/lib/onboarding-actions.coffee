Reflux = require 'reflux'

OnboardingActions = Reflux.createActions [
  "changeAPIEnvironment"
  "loadExternalAuthPage"

  "moveToPreviousPage"
  "moveToPage"
]

for key, action of OnboardingActions
  action.sync = true

module.exports = OnboardingActions
