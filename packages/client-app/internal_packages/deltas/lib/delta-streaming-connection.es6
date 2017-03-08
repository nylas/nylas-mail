import _ from 'underscore'
import {ExponentialBackoffScheduler} from 'isomorphic-core'
import {
  Actions,
  Account,
  APIError,
  N1CloudAPI,
  DatabaseStore,
  DeltaProcessor,
  NylasAPIRequest,
  OnlineStatusStore,
  NylasLongConnection,
} from 'nylas-exports';


const MAX_RETRY_DELAY = 5 * 60 * 1000; // 5 minutes
const BASE_RETRY_DELAY = 1000;

class DeltaStreamingConnection {
  constructor(account) {
    this._account = account
    this._state = null
    this._longConnection = null
    this._writeStateDebounced = _.debounce(this._writeState, 100)
    this._unsubscribers = []
    this._backoffScheduler = new ExponentialBackoffScheduler({
      baseDelay: BASE_RETRY_DELAY,
      maxDelay: MAX_RETRY_DELAY,
    })

    this._setupListeners()
    NylasEnv.onBeforeUnload = (readyToUnload) => {
      this._writeState().finally(readyToUnload)
    }
  }

  account() {
    return this._account
  }

  async start() {
    try {
      if (!this._state) {
        this._state = await this._loadState()
      }
      const {cursor = 0} = this._state
      this._longConnection = new NylasLongConnection({
        api: N1CloudAPI,
        accountId: this._account.id,
        path: `/delta/streaming?cursor=${cursor}`,
        throttleResultsInterval: 1000,
        closeIfDataStopsInterval: 15 * 1000,
        onError: this._onError,
        onResults: this._onResults,
        onStatusChanged: this._onStatusChanged,
      })
      this._longConnection.start()
    } catch (err) {
      this._onError(err)
    }
  }

  restart() {
    try {
      this._restarting = true
      this.close();
      this._disposeListeners()
      this._setupListeners()
      this.start();
    } finally {
      this._restarting = false
    }
  }

  close() {
    this._disposeListeners()
    this._longConnection.close()
  }

  end() {
    this._state = null
    this._disposeListeners()
    this._longConnection.end()
  }

  _setupListeners() {
    this._unsubscribers = [
      Actions.retryDeltaConnection.listen(this.restart, this),
      OnlineStatusStore.listen(this._onOnlineStatusChanged, this),
    ]
  }

  _disposeListeners() {
    this._unsubscribers.forEach(usub => usub())
    this._unsubscribers = []
  }

  _onOnlineStatusChanged = () => {
    if (OnlineStatusStore.isOnline()) {
      this.restart()
    }
  }

  _onStatusChanged = (status) => {
    if (this._restarting) { return; }
    this._state.status = status;
    this._writeStateDebounced();
    const {Closed, Connected} = NylasLongConnection.Status
    if (status === Connected) {
      this._backoffScheduler.reset()
    }
    if (status === Closed) {
      setTimeout(() => this.restart(), this._backoffScheduler.nextDelay());
    }
  }

  _onResults = (deltas = []) => {
    this._backoffScheduler.reset()

    const last = _.last(deltas);
    if (last && last.cursor) {
      this._setCursor(last.cursor)
    }
    DeltaProcessor.process(deltas, {source: 'n1Cloud'})
  }

  _onError = (err = {}) => {
    if (err.message && err.message.includes('Invalid cursor')) {
      // TODO is this still necessary?
      const error = new Error('DeltaStreamingConnection: Cursor is invalid. Need to blow away local cache.');
      NylasEnv.reportError(error)
      this._setCursor(0)
      DatabaseStore._handleSetupError(error)
      return
    }

    if (err instanceof APIError && err.statusCode === 401) {
      Actions.updateAccount(this._account.id, {
        syncState: Account.SYNC_STATE_AUTH_FAILED,
        syncError: err.toJSON(),
      })
    }

    err.message = `Error connecting to delta stream: ${err.message}`
    if (!NylasAPIRequest.NonReportableStatusCodes.includes(err.statusCode)) {
      NylasEnv.reportError(err)
    }
    this.close()

    setTimeout(() => this.restart(), this._backoffScheduler.nextDelay());
  }

  _setCursor = (cursor) => {
    this._state.cursor = cursor;
    this._writeStateDebounced();
  }

  async _loadState() {
    const json = await DatabaseStore.findJSONBlob(`DeltaStreamingConnectionStatus:${this._account.id}`)
    if (json) {
      return json
    }

    // Migrate from old storage key
    const oldState = await DatabaseStore.findJSONBlob(`NylasSyncWorker:${this._account.id}`)
    if (!oldState) {
      return {cursor: null, status: null};
    }

    const {deltaCursors = {}, deltaStatus = {}} = oldState
    return {
      cursor: deltaCursors.n1Cloud,
      status: deltaStatus.n1Cloud,
    }
  }

  async _writeState() {
    if (!this._state) { return }
    await DatabaseStore.inTransaction(t =>
      t.persistJSONBlob(`DeltaStreamingConnectionStatus:${this._account.id}`, this._state)
    );
  }

}

export default DeltaStreamingConnection
