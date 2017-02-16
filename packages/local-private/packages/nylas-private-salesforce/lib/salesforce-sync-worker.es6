import {DatabaseStore, Actions} from 'nylas-exports'
import SalesforceEnv from './salesforce-env'
import SalesforceActions from './salesforce-actions'
import SalesforceObject from './models/salesforce-object'
import SalesforceDataReset from './salesforce-data-reset'
import SyncSalesforceObjectsTask from './tasks/sync-salesforce-objects-task'


// How often we poll Salesforce and pull down all new objects (in sec)
const REFRESH_INTERVAL = 1000 * 60 * 10; // (10 minutes)

// The list of objects we optimistically pull down a full set of
const ObjectTypes = [
  "User",
  "Case",
  "Contact",
  "Account",
  "Opportunity",
  "OpportunityContactRole",
]

function getMostRecentUpdateTime(objectType) {
  return DatabaseStore.findBy(SalesforceObject, {type: objectType})
  .order(SalesforceObject.attributes.updatedAt.descending())
  .limit(1)
  .then((obj = {}) => obj.updatedAt);
}

class SalesforceSyncWorker {

  activate() {
    this._disposables = [
      NylasEnv.config.onDidChange('salesforce.id', this._resetLocalData),
    ]
    this._unsubscribers = [
      SalesforceActions.syncSalesforce.listen(this._run),
      SalesforceActions.logoutOfSalesforce.listen(this._onLogout),
    ]

    this._interval = setInterval(this._run, REFRESH_INTERVAL);

    // Give the app time to bootup before queuing these resource-intensive
    // tasks.
    setTimeout(this._run, 3000)
  }

  deactivate() {
    this._disposables.forEach((disp) => disp.dispose())
    this._unsubscribers.forEach((usub) => usub())
    clearInterval(this._interval)
  }

  _run = () => {
    if (!SalesforceEnv.isLoggedIn()) { return; }
    ObjectTypes.forEach((objectType) => {
      getMostRecentUpdateTime(objectType)
      .then((lastUpdateTime = 0) => {
        const task = new SyncSalesforceObjectsTask({objectType, lastUpdateTime})
        Actions.queueTask(task)
      })
    })
  }

  _onLogout = () => {
    clearInterval(this._interval)
  }

  _resetLocalData = () => {
    if (!SalesforceEnv.isLoggedIn()) { return Promise.resolve(); }

    clearInterval(this._interval)
    this._interval = setInterval(this._run, REFRESH_INTERVAL);
    return SalesforceDataReset.deleteAllData().then(this._run);
  }
}

export default new SalesforceSyncWorker()
