Reflux = require 'reflux'

OnboardingActions = Reflux.createActions [
  "changeAPIEnvironment"
  "loadExternalAuthPage"
  "closeWindow"
  "moveToPreviousPage"
  "moveToPage"
  "accountJSONReceived"
  "retryCheckTokenAuthStatus"
]

for key, action of OnboardingActions
  action.sync = true

module.exports = OnboardingActions
