import _ from 'underscore'
import {
  Actions,
  NylasAPI,
  Thread,
  DatabaseStore,
  FocusedContentStore,
  MutableQuerySubscription,
} from 'nylas-exports'
import SearchActions from './search-actions'

const {LongConnectionStatus} = NylasAPI


class SearchQuerySubscription extends MutableQuerySubscription {

  constructor(searchQuery, accountIds) {
    super(null, {emitResultSet: true})
    this._searchQuery = searchQuery
    this._accountIds = accountIds

    this.resetData()

    this._connections = []
    this._unsubscribers = [
      FocusedContentStore.listen(::this.onFocusedContentChanged),
    ]
    _.defer(() => this.performSearch())
  }

  replaceRange = () => {
    // TODO
  }

  resetData() {
    this._searchStartedAt = null
    this._resultsReceivedAt = null
    this._firstThreadSelectedAt = null
    this._lastFocusedThread = null
    this._focusedThreadCount = 0
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
    dbQuery = dbQuery
    .search(this._searchQuery)
    .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
    .limit(30)

    dbQuery.then((results) => {
      if (results.length > 0) {
        this.replaceQuery(dbQuery)
      }
    })
  }

  performRemoteSearch() {
    const accountsSearched = new Set()
    let resultIds = []

    const allAccountsSearched = () => accountsSearched.size === this._accountIds.length
    const resultsReturned = () => {
      // Don't emit a "result" until we have at least one thread to display.
      // Otherwise it will show "No Results Found"
      if (resultIds.length > 0 || allAccountsSearched()) {
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
        onStatusChanged: (status) => {
          const hasClosed = [
            LongConnectionStatus.Closed,
            LongConnectionStatus.Ended,
          ].includes(status)

          if (hasClosed) {
            accountsSearched.add(accountId)
            if (allAccountsSearched()) {
              SearchActions.searchCompleted()
            }
            resultsReturned()
          }
        },
      })
    })
  }

  onFocusedContentChanged() {
    const thread = FocusedContentStore.focused('thread')
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
    const timeInsideSearch = Math.round((Date.now() - this._searchStartedAt) / 1000)
    const numItems = this._focusedThreadCount
    const didSelectAnyThreads = numItems > 0

    if (this._firstThreadSelectedAt) {
      timeToFirstThreadSelected = Math.round((this._firstThreadSelectedAt - this._searchStartedAt) / 1000)
    }
    if (this._resultsReceivedAt) {
      timeToFirstServerResults = Math.round((this._resultsReceivedAt - this._searchStartedAt) / 1000)
    }

    const data = {
      numItems,
      timeInsideSearch,
      didSelectAnyThreads,
      timeToFirstServerResults,
      timeToFirstThreadSelected,
    }
    Actions.recordUserEvent("Search Performed", data)
    this.resetData()
  }

  onLastCallbackRemoved() {
    this.reportSearchMetrics();
    this._connections.forEach((conn) => conn.end())
    this._unsubscribers.forEach((unsub) => unsub())
  }
}

export default SearchQuerySubscription
