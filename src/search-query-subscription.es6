import _ from 'underscore'
import Actions from './flux/actions'
import NylasAPI from './flux/nylas-api'
import Thread from './flux/models/thread'
import DatabaseStore from './flux/stores/database-store'
import MutableQuerySubscription from './flux/models/mutable-query-subscription'

let FocusedPerspectiveStore = null


class SearchQuerySubscription extends MutableQuerySubscription {

  constructor(searchQuery, accountIds) {
    FocusedPerspectiveStore = require('./flux/stores/focused-content-store')

    super(null, {asResultSet: true})
    this._searchQuery = searchQuery
    this._accountIds = accountIds

    this.resetData()

    this._connections = []
    this._unsubscribers = [
      FocusedPerspectiveStore.listen(::this.onFocusedContentChanged),
    ]
    _.defer(() => this.performSearch())
  }

  resetData() {
    this._searchStartedAt = null
    this._resultsReceivedAt = null
    this._firstThreadSelectedAt = null
    this._lastFocusedThread = null
    this._focusedThreadCount = 0
  }

  replaceRange = () => {
    // TODO
  }

  performSearch() {
    this._searchStartedAt = Date.now()

    this.performLocalSearch()
    this.performRemoteSearch()
  }

  performLocalSearch() {
    let dbQuery = DatabaseStore.findAll(Thread)
    if (this._accountIds.length === 1) {
      dbQuery = dbQuery.where({accountId: this._accountIds[0]})
    }
    dbQuery = dbQuery.search(this._searchQuery).limit(30)
    dbQuery.then((results) => {
      if (results.length > 0) {
        this.replaceQuery(dbQuery)
      }
    })
  }

  performRemoteSearch() {
    const accountsSearched = new Set()
    let resultIds = []

    const resultsReturned = () => {
      // Don't emit a "result" until we have at least one thread to display.
      // Otherwise it will show "No Results Found"
      if (resultIds.length > 0 || accountsSearched.size === this._accountIds.length) {
        const currentResults = this._set && this._set.ids().length > 0
        if (currentResults) {
          const currentResultIds = this._set.ids()
          resultIds = _.uniq(currentResultIds.concat(resultIds))
        }
        const dbQuery = (
          DatabaseStore.findAll(Thread)
          .where({id: resultIds})
          .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
        )
        this.replaceQuery(dbQuery)
      }
    }

    this._connections = this._accountIds.map((accountId) => {
      return NylasAPI.startLongConnection({
        accountId,
        path: `/threads/search/streaming?q=${encodeURIComponent(this._searchQuery)}`,
        onResults: (results) => {
          if (!this._resultsReceivedAt) {
            this._resultsReceivedAt = Date.now()
          }
          const threads = results[0]
          resultIds = resultIds.concat(_.pluck(threads, 'id'))
          resultsReturned()
        },
        onStatusChanged: (conn) => {
          if (conn.isClosed()) {
            accountsSearched.add(accountId)
            resultsReturned()
          }
        },
      })
    })
  }

  onFocusedContentChanged() {
    const thread = FocusedPerspectiveStore.focused('thread')
    const shouldRecordChange = (
      thread &&
      (this._lastFocusedThread || {}).id !== thread.id
    )
    if (shouldRecordChange) {
      if (this._focusedThreadCount === 0) {
        this._firstThreadSelectedAt = Date.now()
      }
      this._focusedThreadCount += 1
      this._lastFocusedThread = thread
    }
  }

  reportSearchMetrics() {
    if (!this._searchStartedAt) {
      return;
    }

    let timeToFirstServerResults = null;
    let timeToFirstThreadSelected = null;
    const searchQuery = this._searchQuery
    const timeInsideSearch = Math.round((Date.now() - this._searchStartedAt) / 1000)
    const selectedThreads = this._focusedThreadCount
    const didSelectAnyThreads = selectedThreads > 0

    if (this._firstThreadSelectedAt) {
      timeToFirstThreadSelected = Math.round((this._firstThreadSelectedAt - this._searchStartedAt) / 1000)
    }
    if (this._resultsReceivedAt) {
      timeToFirstServerResults = Math.round((this._resultsReceivedAt - this._searchStartedAt) / 1000)
    }

    const data = {
      searchQuery,
      selectedThreads,
      timeInsideSearch,
      didSelectAnyThreads,
      timeToFirstServerResults,
      timeToFirstThreadSelected,
    }
    Actions.recordUserEvent("Search Performed", data)
    this.resetData()
  }

  cleanup() {
    this._connections.forEach((conn) => conn.end())
    this._unsubscribers.forEach((unsub) => unsub())
  }

  removeCallback(callback) {
    super.removeCallback(callback)

    if (this.callbackCount() === 0) {
      this.reportSearchMetrics()
      this.cleanup()
    }
  }
}

module.exports = SearchQuerySubscription
