import {DatabaseStore} from 'nylas-exports'
import SalesforceObject from './models/salesforce-object'
import SalesforceSchema from './models/salesforce-schema'
import SalesforceActions from './salesforce-actions'

const SALESFORCE_DATA_VERSION = 1;
const CONFIG_KEY = "salesforceDataVersion"

class SalesforceDataReset {
  activate() {
    const version = NylasEnv.config.get(CONFIG_KEY);
    if (version !== SALESFORCE_DATA_VERSION) {
      this.deleteAllData().then(() => {
        SalesforceActions.syncSalesforce();
        NylasEnv.config.set(CONFIG_KEY, SALESFORCE_DATA_VERSION)
      })
    }
  }

  deactivate() {
    return true
  }

  deleteAllData() {
    return DatabaseStore.inTransaction((t) => {
      return Promise.all([
        t.removeAllOfClass(SalesforceObject),
        t.removeAllOfClass(SalesforceSchema),
      ])
    });
  }
}
export default new SalesforceDataReset()
