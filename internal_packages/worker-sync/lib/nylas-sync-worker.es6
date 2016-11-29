import _ from 'underscore';
import { NylasAPIRequest, NylasAPI, N1CloudAPI, Actions, DatabaseStore, NylasSyncStatusStore, NylasLongConnection } from 'nylas-exports';
import DeltaStreamingConnection from './delta-streaming-connection';
import ContactRankingsCache from './contact-rankings-cache';

const INITIAL_PAGE_SIZE = 30;
const MAX_PAGE_SIZE = 100;

// BackoffTimer is a small helper class that wraps setTimeout. It fires the function
// you provide at a regular interval, but backs off each time you call `backoff`.
//
class BackoffTimer {
  constructor(fn) {
    this.fn = fn;
    this.resetDelay();
  }

  cancel = () => {
    if (this._timeout) { clearTimeout(this._timeout); }
    this._timeout = null;
  }

  backoff = (delay) => {
    this._delay = delay != null ? delay : Math.min(this._delay * 1.7, 5 * 1000 * 60); // Cap at 5 minutes
    // Add "full" jitter (see: https://www.awsarchitectureblog.com/2015/03/backoff.html)
    this._actualDelay = Math.random() * this._delay;
    if (!NylasEnv.inSpecMode()) {
      console.log(`Backing off after sync failure. Will retry in ${Math.floor(this._actualDelay / 1000)} seconds.`);
    }
  }

  start = () => {
    if (this._timeout) { clearTimeout(this._timeout); }
    this._timeout = setTimeout(() => {
      this._timeout = null;
      return this.fn();
    }
    , this._actualDelay);
  }

  resetDelay = () => {
    this._delay = 2 * 1000;
    this._actualDelay = Math.random() * this._delay;
  }

  getCurrentDelay = () => {
    return this._delay;
  }
}


/**
 * This manages the syncing of N1 assets. We create one worker per email
 * account. We save the state of the worker in the database.
 *
 * The `state` takes the following schema:
 * this._state = {
 *   "initialized": true,
 *   "deltaCursors": {
 *     n1Cloud: 523,
 *     localSync: 1108,
 *   }
 *   "deltaStatus": {
 *     n1Cloud: "closed",
 *     localSync: "connecting",
 *   }
 *   "nextRetryTimestamp": 123,
 *   "nextRetryDelay": 123,
 *   "threads": { busy: true, complete: false },
 *   "messages": { busy: true, complete: true },
 *   ... (see NylasSyncStatusStore.ModelsForSync for remaining models)
 * }
 *
 * It can be null to indicate
 */
export default class NylasSyncWorker {

  constructor(account) {
    this._state = { initialized: false, deltaCursors: {}, deltaStatus: {} }
    this._account = account;
    this._unlisten = Actions.retrySync.listen(this._onRetrySync.bind(this), this);
    this._terminated = false;
    this._resumeTimer = new BackoffTimer(() => this._resume());
    this._deltaStreams = this._setupDeltaStreams(account);
    this._refreshingCaches = [new ContactRankingsCache(account.id)];

    this._loadStateFromDatabase()
    .then(this._resume)
  }

  _loadStateFromDatabase() {
    return DatabaseStore.findJSONBlob(`NylasSyncWorker:${this._account.id}`).then(json => {
      this._state.initialized = true;
      if (!json) return;
      this._state = json;
      this._state.initialized = true;
      if (!this._state.deltaCursors) this._state.deltaCursors = {}
      if (!this._state.deltaStatus) this._state.deltaStatus = {}
      for (const key of NylasSyncStatusStore.ModelsForSync) {
        if (this._state[key]) { this._state[key].busy = false; }
      }
    });
  }

  _setupDeltaStreams = (account) => {
    const localSync = new DeltaStreamingConnection(NylasAPI,
        account.id, this._deltaStreamOpts("localSync"));

    const n1Cloud = new DeltaStreamingConnection(N1CloudAPI,
        account.id, this._deltaStreamOpts("n1Cloud"));

    return {localSync, n1Cloud};
  }

  _deltaStreamOpts = (streamName) => {
    return {
      isReady: () => this._state.initialized,
      getCursor: () => this._state.deltaCursors[streamName],
      setCursor: val => {
        this._state.deltaCursors[streamName] = val;
        this._writeState();
      },
      onStatusChanged: (status, statusCode) => {
        this._state.deltaStatus[streamName] = status;
        if (status === NylasLongConnection.Status.Closed) {
          if (statusCode === 403) {
            // Make the delay 30 seconds if we get a 403
            this._backoff(30 * 1000)
          } else {
            this._backoff();
          }
        } else if (status === NylasLongConnection.Status.Connected) {
          this._resumeTimer.resetDelay();
        }
        this._writeState();
      },
    }
  }

  account() {
    return this._account;
  }

  deltaStreams() {
    return this._deltaStreams;
  }

  state() {
    return this._state;
  }

  busy() {
    if (!this._state.initialized) { return false; }
    return _.any(this._state, ({busy} = {}) => busy)
  }

  start() {
    this._resumeTimer.start();
    _.map(this._deltaStreams, s => s.start())
    this._refreshingCaches.map(c => c.start());
    return this._resume();
  }

  cleanup() {
    this._unlisten();
    this._resumeTimer.cancel();
    _.map(this._deltaStreams, s => s.end())
    this._refreshingCaches.map(c => c.end());
    this._terminated = true;
  }

  _resume = () => {
    if (!this._state.initialized) { return Promise.resolve(); }

    _.map(this._deltaStreams, s => s.start())

    // Stop the timer. If one or more network requests fails during the
    // fetch process we'll backoff and restart the timer.
    this._resumeTimer.cancel();

    const needed = [
      {model: 'threads'},
      {model: 'messages', maxFetchCount: 5000},
      {model: 'folders', initialPageSize: 1000},
      {model: 'labels', initialPageSize: 1000},
      {model: 'drafts'},
      {model: 'contacts'},
      {model: 'calendars'},
      {model: 'events'},
    ].filter(this._shouldFetchCollection.bind(this));

    if (needed.length === 0) { return Promise.resolve(); }

    return this._fetchMetadata()
    .then(() => Promise.each(needed, this._fetchCollection.bind(this)));
  }

  _fetchMetadata(offset = 0) {
    const limit = 200;
    const request = new NylasAPIRequest({
      api: N1CloudAPI,
      options: {
        accountId: this._account.id,
        returnsModel: false,
        path: "/metadata",
        qs: {limit, offset},
      },
    })
    return request.run().then(data => {
      if (this._terminated) { return Promise.resolve(); }
      for (const metadatum of data) {
        if (this._metadata[metadatum.object_id] == null) { this._metadata[metadatum.object_id] = []; }
        this._metadata[metadatum.object_id].push(metadatum);
      }
      if (data.length === limit) {
        return this.fetchMetadata(offset + limit);
      }
      console.log(`Retrieved ${offset + data.length} metadata objects`);
      return Promise.resolve();
    }).catch(() => {
      if (this._terminated) { return; }
      this._backoff();
    });
  }

  _shouldFetchCollection({model} = {}) {
    if (!this._state.initialized) { return false; }
    const state = this._state[model] != null ? this._state[model] : {};

    if (state.complete) { return false; }
    if (state.busy) { return false; }
    return true;
  }

  _fetchCollection({model, initialPageSize, maxFetchCount} = {}) {
    const pageSize = initialPageSize || INITIAL_PAGE_SIZE;
    const state = this._state[model] != null ? this._state[model] : {};
    state.complete = false;
    state.error = null;
    state.busy = true;
    if (state.fetched == null) { state.fetched = 0; }
    if (state.count == null) { state.count = 0; }

    if (state.lastRequestRange) {
      let {limit} = state.lastRequestRange;
      const {offset} = state.lastRequestRange;
      if (state.fetched + limit > maxFetchCount) {
        limit = maxFetchCount - state.fetched;
      }
      state.lastRequestRange = null;
      this._fetchCollectionPage(model, {limit, offset}, {maxFetchCount});
    } else {
      let limit = pageSize;
      if (state.fetched + limit > maxFetchCount) {
        limit = maxFetchCount - state.fetched;
      }
      this._fetchCollectionPage(model, {
        limit,
        offset: 0,
      }, {maxFetchCount});
    }

    this._state[model] = state;
    return this._writeState();
  }

  _fetchCollectionPage(model, params = {}, options = {}) {
    const requestStartTime = Date.now();
    const requestOptions = {
      metadataToAttach: this._metadata,

      error: err => {
        if (this._terminated) { return; }
        this._onFetchCollectionPageError(model, params, err);
      },

      success: json => {
        if (this._terminated) { return; }

        if (["labels", "folders"].includes(model) && this._hasNoInbox(json)) {
          this._onFetchCollectionPageError(model, params, `No inbox in ${model}`);
          return;
        }

        const lastReceivedIndex = params.offset + json.length;
        const moreToFetch = options.maxFetchCount ?
          json.length === params.limit && lastReceivedIndex < options.maxFetchCount
        :
          json.length === params.limit;

        if (moreToFetch) {
          const nextParams = _.extend({}, params, {offset: lastReceivedIndex});
          let limit = Math.min(Math.round(params.limit * 1.5), MAX_PAGE_SIZE);
          if (options.maxFetchCount) {
            limit = Math.min(limit, options.maxFetchCount - lastReceivedIndex);
          }
          nextParams.limit = limit;
          const nextDelay = Math.max(0, 1500 - (Date.now() - requestStartTime));
          setTimeout((() => this._fetchCollectionPage(model, nextParams, options)), nextDelay);
        }

        this._updateTransferState(model, {
          fetched: lastReceivedIndex,
          busy: moreToFetch,
          complete: !moreToFetch,
          lastRequestRange: {offset: params.offset, limit: params.limit},
          error: null,
        });
      },
    };

    if (model === 'threads') {
      return NylasAPI.getThreads(this._account.id, params, requestOptions);
    }
    return NylasAPI.getCollection(this._account.id, model, params, requestOptions);
  }

  // It's occasionally possible for the NylasAPI's labels or folders
  // endpoint to not return an "inbox" label. Since that's a core part of
  // the app and it doesn't function without it, keep retrying until we see
  // it.
  _hasNoInbox(json) {
    return !_.any(json, obj => obj.name === "inbox");
  }

  _onFetchCollectionPageError(model, params, err) {
    this._backoff();
    this._updateTransferState(model, {
      busy: false,
      complete: false,
      error: err.toString(),
      lastRequestRange: {offset: params.offset, limit: params.limit},
    });
  }

  _backoff(delay) {
    this._resumeTimer.backoff(delay);
    this._resumeTimer.start();
    this._state.nextRetryDelay = this._resumeTimer.getCurrentDelay();
    this._state.nextRetryTimestamp = Date.now() + this._state.nextRetryDelay;
  }

  _updateTransferState(model, updatedKeys) {
    this._state[model] = _.extend(this._state[model], updatedKeys);
    this._writeState();
  }

  _writeState() {
    if (this.__writeState == null) {
      this.__writeState = _.debounce(() => {
        DatabaseStore.inTransaction(t => {
          t.persistJSONBlob(`NylasSyncWorker:${this._account.id}`, this._state);
        });
      }, 100);
    }
    this.__writeState();
  }

  _onRetrySync() {
    this._resumeTimer.resetDelay();
    return this._resume();
  }
}

NylasSyncWorker.BackoffTimer = BackoffTimer;
NylasSyncWorker.MAX_PAGE_SIZE = MAX_PAGE_SIZE;
NylasSyncWorker.INITIAL_PAGE_SIZE = INITIAL_PAGE_SIZE;
