import NylasStore from 'nylas-store';
import { Thread, Actions, ContactStore, AccountStore, DatabaseStore, FocusedPerspectiveStore } from 'nylas-exports';

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
      const next = new SearchMailboxPerspective(current.accountIds, this._searchQuery.trim());
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

    const databaseQuery = DatabaseStore.findAll(Thread)
      .where(Thread.attributes.subject.like(this._searchQuery))
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
      .limit(4);

    const {accountIds} = FocusedPerspectiveStore.current();
    if (accountIds instanceof Array) {
      databaseQuery.where(Thread.attributes.accountId.in(accountIds));
    }

    databaseQuery.then(results => {
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

    this.trigger();
  }
}

export default new SearchStore();
