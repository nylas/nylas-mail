import _ from 'underscore';
import {
  Actions,
  Thread,
  DatabaseStore,
  SearchQueryParser,
  ComponentRegistry,
  FocusedContentStore,
  MutableQuerySubscription,
} from 'mailspring-exports';
import SearchActions from './search-actions';

class SearchQuerySubscription extends MutableQuerySubscription {
  constructor(searchQuery, accountIds) {
    super(null, { emitResultSet: true });
    this._searchQuery = searchQuery;
    this._accountIds = accountIds;

    this.resetData();

    this._connections = [];
    this._unsubscribers = [FocusedContentStore.listen(() => this.onFocusedContentChanged())];
    this._extDisposables = [];

    _.defer(() => this.performSearch());
  }

  replaceRange = () => {
    // TODO
  };

  resetData() {
    this._searchStartedAt = null;
    this._resultsReceivedAt = null;
    this._firstThreadSelectedAt = null;
    this._lastFocusedThread = null;
    this._focusedThreadCount = 0;
  }

  performSearch() {
    this._searchStartedAt = Date.now();

    this.performLocalSearch();
    this.performRemoteSearch();
    this.performExtensionSearch();
  }

  performLocalSearch() {
    let dbQuery = DatabaseStore.findAll(Thread).distinct();
    if (this._accountIds.length === 1) {
      dbQuery = dbQuery.where({ accountId: this._accountIds[0] });
    }
    try {
      const parsedQuery = SearchQueryParser.parse(this._searchQuery);
      dbQuery = dbQuery.structuredSearch(parsedQuery);
    } catch (e) {
      console.info('Failed to parse local search query, falling back to generic query', e);
      dbQuery = dbQuery.search(this._searchQuery);
    }
    dbQuery = dbQuery.order(Thread.attributes.lastMessageReceivedTimestamp.descending()).limit(100);

    dbQuery.then(results => {
      if (results.length > 0) {
        this.replaceQuery(dbQuery);
      }
    });
  }

  _addThreadIdsToSearch(ids = []) {
    const currentResults = this._set && this._set.ids().length > 0;
    let searchIds = ids;
    if (currentResults) {
      const currentResultIds = this._set.ids();
      searchIds = _.uniq(currentResultIds.concat(ids));
    }
    const dbQuery = DatabaseStore.findAll(Thread)
      .where({ id: searchIds })
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending());
    this.replaceQuery(dbQuery);
  }

  performRemoteSearch() {
    // TODO: Perform IMAP search here.
    //
    // This is temporarily disabled because we support Gmail's
    // advanced syntax locally (eg: in: inbox, is:unread), and
    // search message bodies, so local search is pretty much
    // good enough for v1. Come back and implement this soon!
    //
    setTimeout(() => {
      SearchActions.searchCompleted();
    }, 400);
  }

  performExtensionSearch() {
    const searchExtensions = ComponentRegistry.findComponentsMatching({
      role: 'SearchBarResults',
    });

    this._extDisposables = searchExtensions.map(ext => {
      return ext.observeThreadIdsForQuery(this._searchQuery).subscribe((ids = []) => {
        const allIds = _.compact(_.flatten(ids));
        if (allIds.length === 0) return;
        this._addThreadIdsToSearch(allIds);
      });
    });
  }

  onFocusedContentChanged() {
    const thread = FocusedContentStore.focused('thread');
    const shouldRecordChange = thread && (this._lastFocusedThread || {}).id !== thread.id;
    if (shouldRecordChange) {
      if (this._focusedThreadCount === 0) {
        this._firstThreadSelectedAt = Date.now();
      }
      this._focusedThreadCount += 1;
      this._lastFocusedThread = thread;
    }
  }

  reportSearchMetrics() {
    if (!this._searchStartedAt) {
      return;
    }

    let timeToFirstServerResults = null;
    let timeToFirstThreadSelected = null;
    const timeInsideSearch = Math.round((Date.now() - this._searchStartedAt) / 1000);
    const numItems = this._focusedThreadCount;
    const didSelectAnyThreads = numItems > 0;

    if (this._firstThreadSelectedAt) {
      timeToFirstThreadSelected = Math.round(
        (this._firstThreadSelectedAt - this._searchStartedAt) / 1000
      );
    }
    if (this._resultsReceivedAt) {
      timeToFirstServerResults = Math.round(
        (this._resultsReceivedAt - this._searchStartedAt) / 1000
      );
    }

    const data = {
      numItems,
      timeInsideSearch,
      didSelectAnyThreads,
      timeToFirstServerResults,
      timeToFirstThreadSelected,
    };
    Actions.recordUserEvent('Search Performed', data);
    this.resetData();
  }

  onLastCallbackRemoved() {
    this.reportSearchMetrics();
    this._connections.forEach(conn => conn.end());
    this._unsubscribers.forEach(unsub => unsub());
    this._extDisposables.forEach(disposable => disposable.dispose());
  }
}

export default SearchQuerySubscription;
