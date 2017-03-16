import _ from 'underscore'
import {ExponentialBackoffScheduler} from 'isomorphic-core'
import N1CloudAPI from '../n1-cloud-api'
import Actions from '../flux/actions'
import {APIError} from '../flux/errors'
import Account from '../flux/models/account'
import DeltaProcessor from './delta-processor'
import DatabaseStore from '../flux/stores/database-store'
import IdentityStore from '../flux/stores/identity-store'
import OnlineStatusStore from '../flux/stores/online-status-store'
import NylasLongConnection from '../flux/nylas-long-connection'


const MAX_RETRY_DELAY = 5 * 60 * 1000; // 5 minutes
const BASE_RETRY_DELAY = 1000;

class DeltaStreamingConnection {
  constructor(account) {
    this._account = account
    this._state = null
    this._longConnection = null
    this._retryTimeout = null
    this._unsubscribers = []
    this._writeStateDebounced = _.debounce(this._writeState, 100)
    this._backoffScheduler = new ExponentialBackoffScheduler({
      baseDelay: BASE_RETRY_DELAY,
      maxDelay: MAX_RETRY_DELAY,
    })

    this._setupListeners()
    NylasEnv.onBeforeUnload = (readyToUnload) => {
      this._writeState().finally(readyToUnload)
    }
  }

  async start() {
    try {
      if (!IdentityStore.identity()) {
        console.warn(`Can't start DeltaStreamingConnection without a Nylas Identity`)
        return
      }
      if (!this._state) {
        this._state = await this._loadState()
      }
      const cursor = this._state.cursor || 0
      this._clearRetryTimeout()
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
    this._clearRetryTimeout()
    this._disposeListeners()
    if (this._longConnection) {
      this._longConnection.close()
    }
  }

  end() {
    this._clearRetryTimeout()
    this._disposeListeners()
    if (this._longConnection) {
      this._longConnection.end()
    }
  }

  _setupListeners() {
    this._unsubscribers = [
      Actions.retryDeltaConnection.listen(this.restart, this),
      OnlineStatusStore.listen(this._onOnlineStatusChanged, this),
      IdentityStore.listen(this._onIdentityChanged, this),
    ]
  }

  _disposeListeners() {
    this._unsubscribers.forEach(usub => usub())
    this._unsubscribers = []
  }

  _clearRetryTimeout() {
    clearTimeout(this._retryTimeout)
    this._retryTimeout = null
  }

  _onOnlineStatusChanged = () => {
    if (OnlineStatusStore.isOnline()) {
      this.restart()
    }
  }

  _onIdentityChanged = () => {
    if (IdentityStore.identity()) {
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
      Actions.updateAccount(this._account.id, {
        n1CloudState: Account.N1_CLOUD_STATE_RUNNING,
      })
    }
    if (status === Closed) {
      if (this._retryTimeout) { return }
      this._clearRetryTimeout()
      this._retryTimeout = setTimeout(() => this.restart(), this._backoffScheduler.nextDelay());
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

    err.message = `Error connecting to delta stream: ${err.message}`
    if (!(err instanceof APIError)) {
      NylasEnv.reportError(err)
      return
    }

    if (err.shouldReportError()) {
      // TODO move this check into NylasEnv.reportError()?
      NylasEnv.reportError(err)
    }

    if (err.statusCode === 401) {
      Actions.updateAccount(this._account.id, {
        n1CloudState: Account.N1_CLOUD_STATE_AUTH_FAILED,
      })
    }
  }

  _setCursor = (cursor) => {
    this._state.cursor = cursor;
    this._writeStateDebounced();
  }

  async _loadState() {
    const json = await DatabaseStore.findJSONBlob(`DeltaStreamingConnectionStatus:${this._account.id}`)
    if (json) {
      return {
        cursor: json.cursor || undefined,
        status: json.status || undefined,
      }
    }

    // Migrate from old storage key
    const oldState = await DatabaseStore.findJSONBlob(`NylasSyncWorker:${this._account.id}`)
    if (!oldState) {
      return {
        cursor: undefined,
        status: undefined,
      };
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
