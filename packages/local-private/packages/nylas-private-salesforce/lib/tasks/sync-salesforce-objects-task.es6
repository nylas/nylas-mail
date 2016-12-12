import _ from 'underscore'
import moment from 'moment'
import querystring from "querystring";
import {Task, TaskQueue, DatabaseStore} from 'nylas-exports'
import SalesforceActions from '../salesforce-actions'
import SalesforceAPI from '../salesforce-api'
import SalesforceEnv from '../salesforce-env'
import SalesforceObject from '../models/salesforce-object'
import {upsertBasicObjects, newBasicObjectsQuery} from '../salesforce-object-helpers'


class SyncSalesforceObjectsTask extends Task {

  constructor({objectType, lastUpdateTime} = {}) {
    super()
    this._objectType = objectType
    this._lastUpdateTime = lastUpdateTime
  }

  get objectType() {
    return this._objectType
  }

  performLocal() {
    if (!this._objectType) {
      return Promise.reject(new Error('SyncSalesforceObjectsTask: Must provide an objectType'))
    }
    return Promise.resolve()
  }

  performRemote() {
    if (!SalesforceEnv.isLoggedIn()) { return Promise.resolve(Task.Status.Continue) }

    const queuedSyncs = TaskQueue.findTasks(SyncSalesforceObjectsTask, {objectType: this._objectType})
    if (queuedSyncs.length > 1) {
      return Promise.resolve(Task.Status.Continue)
    }

    console.log(`Salesforce: Syncing ${this._objectType}...`)
    return Promise.all([
      this._fetchNewOrUpdatedObjects(this._objectType, this._lastUpdateTime),
      this._removeOldObjects(this._objectType, this._lastUpdateTime),
    ])
    .then(() => console.log(`Salesforce: Done syncing ${this._objectType}`))
    .then(() => Promise.resolve(Task.Status.Success))
    .catch((err) => {
      SalesforceActions.reportError(err)
      return Promise.resolve([Task.Status.Failed, err])
    })
  }

  _handleFetchResponse = (data) => {
    return upsertBasicObjects(data)
    .then(() => {
      const {done, nextRecordsUrl} = data
      if (!done) {
        const nextPath = nextRecordsUrl.match(/\/query\/.*/)[0];
        if (!nextPath) {
          return Promise.reject(
            new Error(`SyncSalesforceObjectsTask: Could not load all objects of type ${this._objectType}. Invalid nextRecordsUrl: ${nextRecordsUrl}`)
          )
        }
        return SalesforceAPI.makeRequest({
          path: nextPath,
        })
        .then(this._handleFetchResponse)
      }
      return Promise.resolve()
    })
  }

  _fetchNewOrUpdatedObjects(objectType, lastUpdateTime) {
    const lastModifiedDate = moment(+lastUpdateTime).utc().format();
    const where = `LastModifiedDate > ${lastModifiedDate}`;
    const query = newBasicObjectsQuery(objectType, where);

    return SalesforceAPI.makeRequest({
      path: `/query/?${query}`,
    })
    .then(this._handleFetchResponse)
  }

  // See Salesforce API documentation for
  // Geting a List of Deleted Records Within the past 30 days
  _removeOldObjects(objectType, lastUpdateTime) {
    if (lastUpdateTime === 0) { return Promise.resolve(); }

    let start = moment()
    const isTooOld = moment(lastUpdateTime).add(29, 'days').isBefore(start);
    start = isTooOld ?
      start.subtract(29, 'days') : moment(lastUpdateTime);
    const end = moment()
    const query = querystring.stringify({
      start: start.utc().format(),
      end: end.utc().format(),
    });

    return SalesforceAPI.makeRequest({
      path: `/sobjects/${objectType}/deleted/?${query}`,
    })
    .then((data) => {
      const deletedRecords = data.deletedRecords || []
      if (deletedRecords.length === 0) { return Promise.resolve(); }
      const ids = _.pluck(deletedRecords, "id");
      return Promise.all(ids.map((id) =>
        DatabaseStore.find(SalesforceObject, id).then((model) => {
          if (!model) { return Promise.resolve() }
          return DatabaseStore.inTransaction(t => t.unpersistModel(model));
        })
      ));
    })
  }

}

export default SyncSalesforceObjectsTask
