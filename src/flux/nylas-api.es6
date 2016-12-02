/* eslint global-require: 0 */

import _ from 'underscore'
import NylasLongConnection from './nylas-long-connection'
import NylasAPIRequest from './nylas-api-request'
import Account from './models/account'
import Message from './models/message'
import Actions from './actions'
import DatabaseStore from './stores/database-store'

// A 0 code is when an error returns without a status code, like "ESOCKETTIMEDOUT"
const TimeoutErrorCodes = [0, "ETIMEDOUT", "ESOCKETTIMEDOUT", "ECONNRESET", "ENETDOWN", "ENETUNREACH"]
const PermanentErrorCodes = [400, 401, 402, 403, 404, 405, 429, 500, "ENOTFOUND", "ECONNREFUSED", "EHOSTDOWN", "EHOSTUNREACH"]
const CancelledErrorCode = [-123, "ECONNABORTED"]
const SampleTemporaryErrorCode = 504

// Lazy-loaded
let AccountStore = null


class NylasAPIChangeLockTracker {
  constructor() {
    this._locks = {}
  }

  acceptRemoteChangesTo(klass, id) {
    const key = `${klass.name}-${id}`
    return this._locks[key] === undefined
  }

  increment(klass, id) {
    const key = `${klass.name}-${id}`
    this._locks[key] = this._locks[key] || 0
    this._locks[key] += 1
  }

  decrement(klass, id) {
    const key = `${klass.name}-${id}`
    if (!this._locks[key]) return
    this._locks[key] -= 1
    if (this._locks[key] <= 0) {
      delete this._locks[key]
    }
  }

  print() {
    console.log("The following models are locked:")
    console.log(this._locks)
  }
}


class NylasAPI {

  constructor() {
    this._lockTracker = new NylasAPIChangeLockTracker()
    this.APIRoot = "http://localhost:2578"

    this._apiObjectToClassMap = {
      file: require('./models/file').default,
      event: require('./models/event').default,
      label: require('./models/label').default,
      folder: require('./models/folder').default,
      thread: require('./models/thread').default,
      draft: require('./models/message').default,
      account: require('./models/account').default,
      message: require('./models/message').default,
      contact: require('./models/contact').default,
      calendar: require('./models/calendar').default,
      providerSyncbackRequest: require('./models/provider-syncback-request').default,
    }

    this.TimeoutErrorCodes = TimeoutErrorCodes
    this.PermanentErrorCodes = PermanentErrorCodes
    this.CancelledErrorCode = CancelledErrorCode
    this.SampleTemporaryErrorCode = SampleTemporaryErrorCode
    this.LongConnectionStatus = NylasLongConnection.Status
  }

  longConnection = (opts) => {
    const connection = new NylasLongConnection(this, opts.accountId, opts)
    connection.onResults(opts.onResults)
    return connection
  }

  startLongConnection = (opts) => {
    this.longConnection(opts).start()
  }

  /*
  If we make a request that `returnsModel` and we get a 404, we want to handle
  it intelligently and in a centralized way. This method identifies the object
  that could not be found and purges it from local cache.

  Handles: /account/<nid>/<collection>/<id>
  */
  handleModel404 = (modelUrl) => {
    const url = require('url')
    const {pathname} = url.parse(modelUrl, true)
    const components = pathname.split('/')

    let collection = null
    let klassId = null
    let klass = null
    if (components.length === 3) {
      collection = components[1]
      klassId = components[2]
      klass = this._apiObjectToClassMap[collection.slice(0, -1)] // Warning: threads => thread
    }

    if (klass && klassId && klassId.length > 0) {
      if (!NylasEnv.inSpecMode()) {
        console.warn(`Deleting ${klass.name}:${klassId} due to API 404`)
      }

      DatabaseStore.inTransaction((t) =>
        t.find(klass, klassId).then((model) => {
          if (model) {
            return t.unpersistModel(model)
          }
          return Promise.resolve()
        })
      )
    }
    return Promise.resolve()
  }

  handleAuthenticationFailure = (modelUrl, apiToken, apiName) => {
    // Prevent /auth errors from presenting auth failure notices
    if (!apiToken) {
      return Promise.resolve()
    }

    AccountStore = AccountStore || require('./stores/account-store').default
    const account = AccountStore.accounts().find((acc) => {
      const localMatch = AccountStore.tokensForAccountId(acc.id).localSync === apiToken;
      const cloudMatch = AccountStore.tokensForAccountId(acc.id).n1Cloud === apiToken;
      return localMatch || cloudMatch;
    })

    if (account) {
      let syncState = Account.SYNC_STATE_AUTH_FAILED
      if (apiName === "N1CloudAPI") {
        syncState = Account.N1_CLOUD_AUTH_FAILED
      }
      Actions.updateAccount(account.id, {syncState})
    }
    return Promise.resolve()
  }

  /*
   Returns a Promise that resolves when any parsed out models (if any)
   have been created and persisted to the database.
  */
  _handleModelResponse = (jsons) => {
    if (!jsons) {
      return Promise.reject(new Error("handleModelResponse with no JSON provided"))
    }

    let response = jsons
    if (!(response instanceof Array)) {
      response = [response]
    }
    if (response.length === 0) {
      return Promise.resolve([])
    }

    const type = response[0].object
    const Klass = this._apiObjectToClassMap[type]
    if (!Klass) {
      console.warn(`NylasAPI::handleModelResponse: Received unknown API object type: ${type}`)
      return Promise.resolve([])
    }

    // Step 1: Make sure the list of objects contains no duplicates, which cause
    // problems downstream when we try to write to the database.
    const uniquedJSONs = _.uniq(response, false, (model) => { return model.id })
    if (uniquedJSONs.length < response.length) {
      console.warn("NylasAPI::handleModelResponse: called with non-unique object set. Maybe an API request returned the same object more than once?")
    }

    // Step 2: Filter out any objects we've locked (usually because we successfully
    // deleted them moments ago).
    const unlockedJSONs = _.filter(uniquedJSONs, (json) => {
      if (this._lockTracker.acceptRemoteChangesTo(Klass, json.id) === false) {
        if (json && json._delta) {
          json._delta.ignoredBecause = "Model is locked, possibly because it's already been deleted."
        }
        return false
      }
      return true
    })

    if (unlockedJSONs.length === 0) {
      return Promise.resolve([])
    }

    // Step 3: Retrieve any existing models from the database for the given IDs.
    const ids = _.pluck(unlockedJSONs, 'id')
    return DatabaseStore.findAll(Klass)
    .where(Klass.attributes.id.in(ids))
    .then((models) => {
      const existingModels = {}
      for (const model of models) {
        existingModels[model.id] = model
      }

      const responseModels = []
      const changedModels = []

      // Step 4: Merge the response data into the existing data for each model,
      // skipping changes when we already have the given version
      unlockedJSONs.forEach((json) => {
        let model = existingModels[json.id]

        const isSameOrNewerVersion = model && model.version && json.version && model.version >= json.version
        const isAlreadySent = model && model.draft === false && json.draft === true

        if (isSameOrNewerVersion) {
          if (json && json._delta) {
            json._delta.ignoredBecause = `JSON v${json.version} <= model v${model.version}`
          }
        } else if (isAlreadySent) {
          if (json && json._delta) {
            json._delta.ignoredBecause = `Model ${model.id} is already sent!`
          }
        } else {
          model = model || new Klass()
          model.fromJSON(json)
          changedModels.push(model)
        }
        responseModels.push(model)
      })

      // Step 5: Save models that have changed, and then return all of the models
      // that were in the response body.
      DatabaseStore.inTransaction((t) =>
        t.persistModels(changedModels)
      )
      .then(() => {
        return Promise.resolve(responseModels)
      })
    })
  }

  _attachMetadataToResponse = (jsons, metadataToAttach) => {
    if (!metadataToAttach) return
    for (const obj of jsons) {
      if (metadataToAttach[obj.id]) {
        obj.metadata = metadataToAttach[obj.id]
      }
    }
  }

  getThreads = (accountId, params = {}, requestOptions = {}) => {
    const requestSuccess = requestOptions.success
    requestOptions.success = (json) => {
      let messages = []
      for (const result of json) {
        if (result.messages) {
          messages = messages.concat(result.messages)
        }
      }
      if (messages.length > 0) {
        this._attachMetadataToResponse(messages, requestOptions.metadataToAttach)
        this._handleModelResponse(messages)
      }
      if (requestSuccess) {
        requestSuccess(json)
      }
    }

    this.getCollection(accountId, 'threads', params, requestOptions)
  }

  getCollection = (accountId, collection, params = {}, requestOptions = {}) => {
    if (!accountId) {
      throw (new Error("getCollection requires accountId"))
    }
    const requestSuccess = requestOptions.success
    new NylasAPIRequest({
      api: this,
      options: _.extend(requestOptions, {
        path: `/${collection}`,
        accountId: accountId,
        qs: params,
        returnsModel: false,
        success: (jsons) => {
          this._attachMetadataToResponse(jsons, requestOptions.metadataToAttach)
          this._handleModelResponse(jsons)
          if (requestSuccess) {
            requestSuccess(jsons)
          }
        },
      }),
    }).run()
  }

  makeDraftDeletionRequest = (draft) => {
    if (!draft.serverId) return
    this.incrementRemoteChangeLock(Message, draft.serverId)
    new NylasAPIRequest({
      api: this,
      options: {
        path: `/drafts/${draft.serverId}`,
        accountId: draft.accountId,
        method: "DELETE",
        body: {version: draft.version},
        returnsModel: false,
      },
    }).run()
    return
  }

  incrementRemoteChangeLock = (klass, id) => {
    this._lockTracker.increment(klass, id)
  }

  decrementRemoteChangeLock = (klass, id) => {
    this._lockTracker.decrement(klass, id)
  }

  accessTokenForAccountId = (aid) => {
    AccountStore = AccountStore || require('./stores/account-store').default
    return AccountStore.tokensForAccountId(aid).localSync
  }

  authPlugin = () => {
    return Promise.resolve();
  }
}

export default new NylasAPI()
