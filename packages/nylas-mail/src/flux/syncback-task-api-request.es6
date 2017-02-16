import Actions from './actions'
import {APIError} from './errors'
import DatabaseStore from './stores/database-store'
import NylasAPIRequest from './nylas-api-request'
import ProviderSyncbackRequest from './models/provider-syncback-request'

/**
 * This API request is meant to be used for requests that create a
 * SyncbackRequest inside K2. When the initial http request succeeds,
 * this means that the task was created, but we cant tell if the task
 * actually succeeded or failed until some time in the future when its
 * processed inside K2's sync loop.
 *
 * A SyncbackTaskAPIRequest will only resolve until the underlying K2
 * syncback request has actually succeeded, or reject when it fails, by
 * listening to deltas for ProviderSyncbackRequests
 */
class SyncbackTaskAPIRequest {

  static listenForRequest(syncbackRequestId) {
    return new Promise((resolve, reject) => {
      const unsubscribe = Actions.didReceiveSyncbackRequestDeltas
      .listen((syncbackRequests) => {
        const failed = syncbackRequests.find(r => r.id === syncbackRequestId && r.status === 'FAILED')
        const succeeded = syncbackRequests.find(r => r.id === syncbackRequestId && r.status === 'SUCCEEDED')
        if (failed) {
          unsubscribe()
          // TODO fix/standardize this error format with K2
          const error = new APIError({
            error: failed.error,
            body: {
              message: failed.error.message,
              data: failed.error.data,
            },
            statusCode: failed.error.statusCode || 500,
          })
          reject(error)
        } else if (succeeded) {
          unsubscribe()
          resolve(succeeded.responseJSON || {})
        }
      });
    })
  }

  static waitForQueuedRequest(syncbackRequestId) {
    return new Promise(async (resolve, reject) => {
      const syncbackRequest = await DatabaseStore.find(ProviderSyncbackRequest, syncbackRequestId);

      if (syncbackRequest) {
        if (syncbackRequest.status === "SUCCEEDED") {
          return resolve(syncbackRequest.responseJSON)
        } else if (syncbackRequest.status === "FAILED") {
          return reject(syncbackRequest.error)
        } // else continue so we listen for it on the delta
      }

      return SyncbackTaskAPIRequest.listenForRequest(syncbackRequestId)
      .then(resolve).catch(reject)
    })
  }

  constructor({api, options}) {
    options.returnsModel = true
    this._request = new NylasAPIRequest({api, options})
    this._onSyncbackRequestCreated = options.onSyncbackRequestCreated || (() => {})
  }

  run() {
    return new Promise(async (resolve, reject) => {
      try {
        const syncbackRequest = await this._request.run()
        await this._onSyncbackRequestCreated(syncbackRequest)
        const syncbackRequestId = syncbackRequest.id
        SyncbackTaskAPIRequest.listenForRequest(syncbackRequestId)
        .then(resolve).catch(reject)
      } catch (err) {
        reject(err)
      }
    })
  }
}

export default SyncbackTaskAPIRequest
