import _ from 'underscore'
import {Reflux} from 'nylas-exports'

const globalSFActions = Reflux.createActions([
  "deleteSuccess",

  "syncbackSuccess",
  "syncbackFailed",

  "salesforceWindowClosing",

  "loginToSalesforce",
  "logoutOfSalesforce",

  "syncSalesforce",

  "reportError",
])

const localSFActions = Reflux.createActions([
  "openObjectForm",
])

const SalesforceActions = _.extend({}, localSFActions, globalSFActions)

for (const actionName of Object.keys(SalesforceActions)) {
  SalesforceActions[actionName].sync = true
}

NylasEnv.registerGlobalActions({
  pluginName: "Salesforce",
  actions: globalSFActions,
});

export default SalesforceActions
