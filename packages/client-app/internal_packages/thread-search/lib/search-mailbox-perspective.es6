import {
  Folder,
  ChangeLabelsTask,
  ChangeFolderTask,
  AccountStore,
  CategoryStore,
  TaskFactory,
  MailboxPerspective,
} from 'nylas-exports'
import SearchQuerySubscription from './search-query-subscription'

class SearchMailboxPerspective extends MailboxPerspective {

  constructor(sourcePerspective, searchQuery) {
    super(sourcePerspective.accountIds)
    if (typeof searchQuery !== 'string') {
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
    return TaskFactory.tasksForThreadsByAccountId(threads, (accountThreads, accountId) => {
      const account = AccountStore.accountForId(accountId);
      const dest = account.preferredRemovalDestination();

      if (dest instanceof Folder) {
        return new ChangeFolderTask({
          threads: accountThreads,
          source: "Dragged out of list",
          folder: dest,
        })
      }
      if (dest.role === 'all') {
        // if you're searching and archive something, it really just removes the inbox label
        return new ChangeLabelsTask({
          threads: accountThreads,
          source: "Dragged out of list",
          labelsToRemove: [CategoryStore.getInboxCategory(accountId)],
        })
      }
      throw new Error("Unexpected destination returned from preferredRemovalDestination()");
    });
  }
}

export default SearchMailboxPerspective;
