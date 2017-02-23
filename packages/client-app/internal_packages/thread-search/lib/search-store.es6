import NylasStore from 'nylas-store';
import {
  Thread,
  Actions,
  ContactStore,
  AccountStore,
  DatabaseStore,
  ComponentRegistry,
  FocusedPerspectiveStore,
} from 'nylas-exports';
import {parseSearchQuery} from './search-query-parser'

import SearchActions from './search-actions';
import SearchMailboxPerspective from './search-mailbox-perspective';

// Stores should closely match the needs of a particular part of the front end.
// For example, we might create a "MessageStore" that observes this store
// for changes in selectedThread, "DatabaseStore" for changes to the underlying database,
// and vends up the array used for that view.

class SearchStore extends NylasStore {
  constructor() {
    super();

    this._searchQuery = FocusedPerspectiveStore.current().searchQuery || "";
    this._searchSuggestionsVersion = 1;
    this._isSearching = false;
    this._extensionData = []
    this._clearResults();

    this.listenTo(FocusedPerspectiveStore, this._onPerspectiveChanged);
    this.listenTo(SearchActions.querySubmitted, this._onQuerySubmitted);
    this.listenTo(SearchActions.queryChanged, this._onQueryChanged);
    this.listenTo(SearchActions.searchBlurred, this._onSearchBlurred);
    this.listenTo(SearchActions.searchCompleted, this._onSearchCompleted);
  }

  query() {
    return this._searchQuery;
  }

  queryPopulated() {
    return this._searchQuery && this._searchQuery.trim().length > 0;
  }

  suggestions() {
    return this._suggestions;
  }

  isSearching() {
    return this._isSearching;
  }

  _onSearchCompleted = () => {
    this._isSearching = false;
    this.trigger();
  }

  _onPerspectiveChanged = () => {
    this._searchQuery = FocusedPerspectiveStore.current().searchQuery || "";
    this.trigger();
  }

  _onQueryChanged = (query) => {
    this._searchQuery = query;
    if (this._searchQuery.length <= 1) {
      this.trigger()
      return
    }
    this._compileResults();
    setTimeout(() => this._rebuildResults(), 0);
  }

  _onQuerySubmitted = (query) => {
    this._searchQuery = query;
    const current = FocusedPerspectiveStore.current();

    if (this.queryPopulated()) {
      this._isSearching = true;
      if (this._perspectiveBeforeSearch == null) {
        this._perspectiveBeforeSearch = current;
      }
      const next = new SearchMailboxPerspective(current, this._searchQuery.trim());
      Actions.focusMailboxPerspective(next);
    } else if (current instanceof SearchMailboxPerspective) {
      if (this._perspectiveBeforeSearch) {
        Actions.focusMailboxPerspective(this._perspectiveBeforeSearch);
        this._perspectiveBeforeSearch = null;
      } else {
        Actions.focusDefaultMailboxPerspectiveForAccounts(AccountStore.accounts());
      }
    }

    this._clearResults();
  }

  _onSearchBlurred = () => {
    this._clearResults();
  }

  _clearResults() {
    this._searchSuggestionsVersion = 1;
    this._threadResults = [];
    this._contactResults = [];
    this._suggestions = [];
    this.trigger();
  }

  _rebuildResults() {
    if (!this.queryPopulated()) {
      this._clearResults();
      return;
    }
    this._searchSuggestionsVersion += 1;
    const searchExtensions = ComponentRegistry.findComponentsMatching({
      role: "SearchBarResults",
    })

    Promise.map(searchExtensions, (ext) => {
      return Promise.props({
        label: ext.searchLabel(),
        suggestions: ext.fetchSearchSuggestions(this._searchQuery),
      })
    }).then((extensionData = []) => {
      this._extensionData = extensionData;
      this._compileResults();
    })

    this._fetchThreadResults();
    this._fetchContactResults();
  }

  _fetchContactResults() {
    const version = this._searchSuggestionsVersion;
    ContactStore.searchContacts(this._searchQuery, {limit: 10}).then(contacts => {
      if (version !== this._searchSuggestionsVersion) {
        return;
      }
      this._contactResults = contacts;
      this._compileResults();
    });
  }

  _fetchThreadResults() {
    if (this._fetchingThreadResultsVersion) { return; }
    this._fetchingThreadResultsVersion = this._searchSuggestionsVersion;

    const {accountIds} = FocusedPerspectiveStore.current();
    let dbQuery = DatabaseStore.findAll(Thread).distinct()
    if (Array.isArray(accountIds) && accountIds.length === 1) {
      dbQuery = dbQuery.where({accountId: accountIds[0]})
    }

    try {
      const parsedQuery = parseSearchQuery(this._searchQuery);
      // console.info('Successfully parsed and codegened search query', parsedQuery);
      dbQuery = dbQuery.structuredSearch(parsedQuery);
    } catch (e) {
      // console.info('Failed to parse local search query, falling back to generic query', e);
      dbQuery = dbQuery.search(this._searchQuery);
    }
    dbQuery = dbQuery
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending())

    // console.info(dbQuery.sql());

    dbQuery.background().then(results => {
      // We've fetched the latest thread results - display them!
      if (this._searchSuggestionsVersion === this._fetchingThreadResultsVersion) {
        this._fetchingThreadResultsVersion = null;
        this._threadResults = results;
        this._compileResults();
      // We're behind and need to re-run the search for the latest results
      } else if (this._searchSuggestionsVersion > this._fetchingThreadResultsVersion) {
        this._fetchingThreadResultsVersion = null;
        this._fetchThreadResults();
      } else {
        this._fetchingThreadResultsVersion = null;
      }
    }
    );
  }

  _compileResults() {
    this._suggestions = [];

    this._suggestions.push({
      label: `Message Contains: ${this._searchQuery}`,
      value: this._searchQuery,
    });

    if (this._threadResults.length) {
      this._suggestions.push({divider: 'Threads'});
      for (const thread of this._threadResults) {
        this._suggestions.push({thread});
      }
    }

    if (this._contactResults.length) {
      this._suggestions.push({divider: 'People'});
      for (const contact of this._contactResults) {
        this._suggestions.push({
          contact: contact,
          value: contact.email,
        });
      }
    }

    if (this._extensionData.length) {
      for (const {label, suggestions} of this._extensionData) {
        this._suggestions.push({divider: label});
        this._suggestions = this._suggestions.concat(suggestions)
      }
    }

    this.trigger();
  }
}

export default new SearchStore();
