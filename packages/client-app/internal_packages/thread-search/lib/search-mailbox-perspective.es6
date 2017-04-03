import _ from 'underscore'
import {AccountStore, CategoryStore, TaskFactory, MailboxPerspective} from 'nylas-exports'
import SearchQuerySubscription from './search-query-subscription'

class SearchMailboxPerspective extends MailboxPerspective {

  constructor(sourcePerspective, searchQuery) {
    super(sourcePerspective.accountIds)
    if (!_.isString(searchQuery)) {
      throw new Error("SearchMailboxPerspective: Expected a `string` search query")
    }

    this.searchQuery = searchQuery;
    if (sourcePerspective instanceof SearchMailboxPerspective) {
      this.sourcePerspective = sourcePerspective.sourcePerspective;
    } else {
      this.sourcePerspective = sourcePerspective;
    }

    this.name = `Searching ${this.sourcePerspective.name}`
  }

  _folderScope() {
    // When the inbox is focused we don't specify a folder scope. If the user
    // wants to search just the inbox then they have to specify it explicitly.
    if (this.sourcePerspective.isInbox()) {
      return '';
    }
    const folderQuery = this.sourcePerspective.categories().map((c) => c.displayName).join('" OR in:"');
    return `AND (in:"${folderQuery}")`;
  }

  emptyMessage() {
    return "No search results available"
  }

  isEqual(other) {
    return super.isEqual(other) && other.searchQuery === this.searchQuery
  }

  threads() {
    return new SearchQuerySubscription(`(${this.searchQuery}) ${this._folderScope()}`, this.accountIds)
  }

  canReceiveThreadsFromAccountIds() {
    return false
  }

  tasksForRemovingItems(threads) {
    return TaskFactory.tasksForApplyingCategories({
      source: "Removing from Search Results",
      threads: threads,
      categoriesToAdd: (accountId) => {
        const account = AccountStore.accountForId(accountId)
        return [account.defaultFinishedCategory()]
      },
      categoriesToRemove: (accountId) => {
        return [CategoryStore.getInboxCategory(accountId)]
      },
    })
  }
}

export default SearchMailboxPerspective;
