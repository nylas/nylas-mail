/* eslint global-require: 0 */
/* eslint no-use-before-define: 0 */
import _ from 'underscore';

import Utils from './flux/models/utils';
import TaskFactory from './flux/tasks/task-factory';
import AccountStore from './flux/stores/account-store';
import CategoryStore from './flux/stores/category-store';
import DatabaseStore from './flux/stores/database-store';
import OutboxStore from './flux/stores/outbox-store';
import ThreadCountsStore from './flux/stores/thread-counts-store';
import FolderSyncProgressStore from './flux/stores/folder-sync-progress-store';
import MutableQuerySubscription from './flux/models/mutable-query-subscription';
import UnreadQuerySubscription from './flux/models/unread-query-subscription';
import Thread from './flux/models/thread';
import Category from './flux/models/category';
import Label from './flux/models/label';
import Folder from './flux/models/folder';
import Actions from './flux/actions';

let ChangeStarredTask = null;
let ChangeLabelsTask = null;
let ChangeFolderTask = null;
let ChangeUnreadTask = null;
let FocusedPerspectiveStore = null;

// This is a class cluster. Subclasses are not for external use!
// https://developer.apple.com/library/ios/documentation/General/Conceptual/CocoaEncyclopedia/ClassClusters/ClassClusters.html

export default class MailboxPerspective {
  // Factory Methods
  static forNothing() {
    return new EmptyMailboxPerspective();
  }

  static forDrafts(accountsOrIds) {
    return new DraftsMailboxPerspective(accountsOrIds);
  }

  static forCategory(category) {
    return category ? new CategoryMailboxPerspective([category]) : this.forNothing();
  }

  static forCategories(categories) {
    return categories.length > 0 ? new CategoryMailboxPerspective(categories) : this.forNothing();
  }

  static forStandardCategories(accountsOrIds, ...names) {
    // TODO this method is broken
    const categories = CategoryStore.getCategoriesWithRoles(accountsOrIds, ...names);
    return this.forCategories(categories);
  }

  static forStarred(accountsOrIds) {
    return new StarredMailboxPerspective(accountsOrIds);
  }

  static forUnread(categories) {
    return categories.length > 0 ? new UnreadMailboxPerspective(categories) : this.forNothing();
  }

  static forInbox(accountsOrIds) {
    return this.forStandardCategories(accountsOrIds, 'inbox');
  }

  static fromJSON(json) {
    try {
      if (json.type === CategoryMailboxPerspective.name) {
        const categories = JSON.parse(json.serializedCategories).map(Utils.convertToModel);
        return this.forCategories(categories);
      }
      if (json.type === UnreadMailboxPerspective.name) {
        const categories = JSON.parse(json.serializedCategories).map(Utils.convertToModel);
        return this.forUnread(categories);
      }
      if (json.type === StarredMailboxPerspective.name) {
        return this.forStarred(json.accountIds);
      }
      if (json.type === DraftsMailboxPerspective.name) {
        return this.forDrafts(json.accountIds);
      }
      return this.forInbox(json.accountIds);
    } catch (error) {
      AppEnv.reportError(new Error(`Could not restore mailbox perspective: ${error}`));
      return null;
    }
  }

  // Instance Methods

  constructor(accountIds) {
    this.accountIds = accountIds;
    if (
      !(accountIds instanceof Array) ||
      !accountIds.every(aid => typeof aid === 'string' || typeof aid === 'number')
    ) {
      throw new Error(`${this.constructor.name}: You must provide an array of string "accountIds"`);
    }
  }

  toJSON() {
    return { accountIds: this.accountIds, type: this.constructor.name };
  }

  isEqual(other) {
    if (!other || this.constructor !== other.constructor) {
      return false;
    }
    if (other.name !== this.name) {
      return false;
    }
    if (!_.isEqual(this.accountIds, other.accountIds)) {
      return false;
    }
    return true;
  }

  isInbox() {
    return this.categoriesSharedRole() === 'inbox';
  }

  isSent() {
    return this.categoriesSharedRole() === 'sent';
  }

  isTrash() {
    return this.categoriesSharedRole() === 'trash';
  }

  isArchive() {
    return false;
  }

  emptyMessage() {
    return 'No Messages';
  }

  categories() {
    return [];
  }

  // overwritten in CategoryMailboxPerspective
  hasSyncingCategories() {
    return false;
  }

  categoriesSharedRole() {
    this._categoriesSharedRole =
      this._categoriesSharedRole || Category.categoriesSharedRole(this.categories());
    return this._categoriesSharedRole;
  }

  category() {
    return this.categories().length === 1 ? this.categories()[0] : null;
  }

  threads() {
    throw new Error('threads: Not implemented in base class.');
  }

  unreadCount() {
    return 0;
  }

  // Public:
  // - accountIds {Array} Array of unique account ids associated with the threads
  // that want to be included in this perspective
  //
  // Returns true if the accountIds are part of the current ids, or false
  // otherwise. This means that it checks if I am attempting to move threads
  // between the same set of accounts:
  //
  // E.g.:
  // perpective = Starred for accountIds: a1, a2
  // thread1 has accountId a3
  // thread2 has accountId a2
  //
  // perspective.canReceiveThreadsFromAccountIds([a2, a3]) -> false -> I cant move those threads to Starred
  // perspective.canReceiveThreadsFromAccountIds([a2]) -> true -> I can move that thread to Starred
  canReceiveThreadsFromAccountIds(accountIds) {
    if (!accountIds || accountIds.length === 0) {
      return false;
    }
    const areIncomingIdsInCurrent = _.difference(accountIds, this.accountIds).length === 0;
    return areIncomingIdsInCurrent;
  }

  receiveThreadIds(threadIds) {
    DatabaseStore.modelify(Thread, threadIds).then(threads => {
      const tasks = TaskFactory.tasksForThreadsByAccountId(threads, (accountThreads, accountId) => {
        return this.actionsForReceivingThreads(accountThreads, accountId);
      });
      if (tasks.length > 0) {
        Actions.queueTasks(tasks);
      }
    });
  }

  actionsForReceivingThreads(threads, accountId) {
    // eslint-disable-line
    throw new Error('actionsForReceivingThreads: Not implemented in base class.');
  }

  canArchiveThreads(threads) {
    if (this.isArchive()) {
      return false;
    }
    const accounts = AccountStore.accountsForItems(threads);
    return accounts.every(acc => acc.canArchiveThreads());
  }

  canTrashThreads(threads) {
    return this.canMoveThreadsTo(threads, 'trash');
  }

  canMoveThreadsTo(threads, standardCategoryName) {
    if (this.categoriesSharedRole() === standardCategoryName) {
      return false;
    }
    return AccountStore.accountsForItems(threads).every(
      acc => CategoryStore.getCategoryByRole(acc, standardCategoryName) !== null
    );
  }

  tasksForRemovingItems(threads) {
    if (!(threads instanceof Array)) {
      throw new Error('tasksForRemovingItems: you must pass an array of threads or thread ids');
    }
    return [];
  }
}

class DraftsMailboxPerspective extends MailboxPerspective {
  constructor(accountIds) {
    super(accountIds);
    this.name = 'Drafts';
    this.iconName = 'drafts.png';
    this.drafts = true; // The DraftListStore looks for this
  }

  threads() {
    return null;
  }

  unreadCount() {
    let count = 0;
    for (const aid of this.accountIds) {
      count += OutboxStore.itemsForAccount(aid).length;
    }
    return count;
  }

  canReceiveThreadsFromAccountIds() {
    return false;
  }
}

class StarredMailboxPerspective extends MailboxPerspective {
  constructor(accountIds) {
    super(accountIds);
    this.name = 'Starred';
    this.iconName = 'starred.png';
  }

  threads() {
    const query = DatabaseStore.findAll(Thread)
      .where([Thread.attributes.starred.equal(true), Thread.attributes.inAllMail.equal(true)])
      .limit(0);

    // Adding a "account_id IN (a,b,c)" clause to our query can result in a full
    // table scan. Don't add the where clause if we know we want results from all.
    if (this.accountIds.length < AccountStore.accounts().length) {
      query.where(Thread.attributes.accountId.in(this.accountIds));
    }

    return new MutableQuerySubscription(query, { emitResultSet: true });
  }

  canReceiveThreadsFromAccountIds(...args) {
    return super.canReceiveThreadsFromAccountIds(...args);
  }

  actionsForReceivingThreads(threads, accountId) {
    ChangeStarredTask = ChangeStarredTask || require('./flux/tasks/change-starred-task').default;
    const task = new ChangeStarredTask({
      accountId,
      threads,
      starred: true,
      source: 'Dragged Into List',
    });
    Actions.queueTask(task);
  }

  tasksForRemovingItems(threads) {
    const task = TaskFactory.taskForInvertingStarred({
      threads: threads,
      source: 'Removed From List',
    });
    return [task];
  }
}

class EmptyMailboxPerspective extends MailboxPerspective {
  constructor() {
    super([]);
  }

  threads() {
    // We need a Thread query that will not return any results and take no time.
    // We use lastMessageReceivedTimestamp because it is the first column on an
    // index so this returns zero items nearly instantly. In the future, we might
    // want to make a Query.forNothing() to go along with MailboxPerspective.forNothing()
    const query = DatabaseStore.findAll(Thread)
      .where({ lastMessageReceivedTimestamp: -1 })
      .limit(0);
    return new MutableQuerySubscription(query, { emitResultSet: true });
  }

  canReceiveThreadsFromAccountIds() {
    return false;
  }
}

class CategoryMailboxPerspective extends MailboxPerspective {
  constructor(_categories) {
    super(_.uniq(_categories.map(c => c.accountId)));
    this._categories = _categories;

    if (this._categories.length === 0) {
      throw new Error('CategoryMailboxPerspective: You must provide at least one category.');
    }

    // Note: We pick the display name and icon assuming that you won't create a
    // perspective with Inbox and Sent or anything crazy like that... todo?
    this.name = this._categories[0].displayName;
    if (this._categories[0].role) {
      this.iconName = `${this._categories[0].role}.png`;
    } else {
      this.iconName = this._categories[0] instanceof Label ? 'label.png' : 'folder.png';
    }
  }

  toJSON() {
    const json = super.toJSON();
    json.serializedCategories = JSON.stringify(this._categories);
    return json;
  }

  isEqual(other) {
    return (
      super.isEqual(other) &&
      _.isEqual(this.categories().map(c => c.id), other.categories().map(c => c.id))
    );
  }

  threads() {
    const query = DatabaseStore.findAll(Thread)
      .where([Thread.attributes.categories.containsAny(this.categories().map(c => c.id))])
      .limit(0);

    if (this.isSent()) {
      query.order(Thread.attributes.lastMessageSentTimestamp.descending());
    }

    if (!['spam', 'trash'].includes(this.categoriesSharedRole())) {
      query.where({ inAllMail: true });
    }

    if (this._categories.length > 1 && this.accountIds.length < this._categories.length) {
      // The user has multiple categories in the same account selected, which
      // means our result set could contain multiple copies of the same threads
      // (since we do an inner join) and we need SELECT DISTINCT. Note that this
      // can be /much/ slower and we shouldn't do it if we know we don't need it.
      query.distinct();
    }

    return new MutableQuerySubscription(query, { emitResultSet: true });
  }

  unreadCount() {
    let sum = 0;
    for (const cat of this._categories) {
      sum += ThreadCountsStore.unreadCountForCategoryId(cat.id);
    }
    return sum;
  }

  categories() {
    return this._categories;
  }

  hasSyncingCategories() {
    return !this._categories.every(cat => {
      const representedFolder =
        cat instanceof Folder ? cat : CategoryStore.getAllMailCategory(cat.accountId);
      return FolderSyncProgressStore.isSyncCompleteForAccount(
        cat.accountId,
        representedFolder.path
      );
    });
  }

  isArchive() {
    return this._categories.every(cat => cat.isArchive());
  }

  canReceiveThreadsFromAccountIds(...args) {
    return (
      super.canReceiveThreadsFromAccountIds(...args) &&
      !this._categories.some(c => c.isLockedCategory())
    );
  }

  actionsForReceivingThreads(threads, accountId) {
    FocusedPerspectiveStore =
      FocusedPerspectiveStore || require('./flux/stores/focused-perspective-store').default;
    ChangeLabelsTask = ChangeLabelsTask || require('./flux/tasks/change-labels-task').default;
    ChangeFolderTask = ChangeFolderTask || require('./flux/tasks/change-folder-task').default;

    const current = FocusedPerspectiveStore.current();

    // This assumes that the we don't have more than one category per
    // accountId attached to this perspective
    if (Category.LockedRoles.includes(current.categoriesSharedRole())) {
      return [];
    }

    const myCat = this.categories().find(c => c.accountId === accountId);
    const currentCat = current.categories().find(c => c.accountId === accountId);

    // Don't drag and drop on ourselves
    if (myCat.id === currentCat.id) {
      return [];
    }

    if (myCat.role === 'all' && currentCat instanceof Label) {
      // dragging from a label into All Mail? Make this an "archive" by removing the
      // label. Otherwise (Since labels are subsets of All Mail) it'd have no effect.
      return [
        new ChangeLabelsTask({
          threads,
          source: 'Dragged into list',
          labelsToAdd: [],
          labelsToRemove: [currentCat],
        }),
      ];
    }
    if (myCat instanceof Folder) {
      // dragging to a folder like spam, trash or any IMAP folder? Just change the folder.
      return [
        new ChangeFolderTask({
          threads,
          source: 'Dragged into list',
          folder: myCat,
        }),
      ];
    }

    if (myCat instanceof Label && currentCat instanceof Folder) {
      // dragging from trash or spam into a label? We need to both apply the label and
      // move to the "All Mail" folder.
      return [
        new ChangeFolderTask({
          threads,
          source: 'Dragged into list',
          folder: CategoryStore.getCategoryByRole(accountId, 'all'),
        }),
        new ChangeLabelsTask({
          threads,
          source: 'Dragged into list',
          labelsToAdd: [myCat],
          labelsToRemove: [],
        }),
      ];
    }
    // label to label
    return [
      new ChangeLabelsTask({
        threads,
        source: 'Dragged into list',
        labelsToAdd: [myCat],
        labelsToRemove: [currentCat],
      }),
    ];
  }

  // Public:
  // Returns the tasks for removing threads from this perspective and moving them
  // to the default destination based on the current view:
  //
  // if you're looking at a folder:
  // - spam: null
  // - trash: null
  // - archive: trash
  // - all others: "finished category (archive or trash)"

  // if you're looking at a label
  // - if finished category === "archive" remove the label
  // - if finished category === "trash" move to trash folder, keep labels intact
  //
  tasksForRemovingItems(threads, source = 'Removed from list') {
    ChangeLabelsTask = ChangeLabelsTask || require('./flux/tasks/change-labels-task').default;
    ChangeFolderTask = ChangeFolderTask || require('./flux/tasks/change-folder-task').default;

    // TODO this is an awful hack
    const role = this.isArchive() ? 'archive' : this.categoriesSharedRole();

    if (role === 'spam' || role === 'trash') {
      return [];
    }

    if (role === 'archive') {
      return TaskFactory.tasksForMovingToTrash({ threads, source });
    }

    return TaskFactory.tasksForThreadsByAccountId(threads, (accountThreads, accountId) => {
      const acct = AccountStore.accountForId(accountId);
      const preferred = acct.preferredRemovalDestination();
      const cat = this.categories().find(c => c.accountId === accountId);
      if (cat instanceof Label && preferred.role !== 'trash') {
        const inboxCat = CategoryStore.getInboxCategory(accountId);
        return new ChangeLabelsTask({
          threads: accountThreads,
          labelsToAdd: [],
          labelsToRemove: [cat, inboxCat],
          source: source,
        });
      }
      return new ChangeFolderTask({
        threads: accountThreads,
        folder: preferred,
        source: source,
      });
    });
  }
}

class UnreadMailboxPerspective extends CategoryMailboxPerspective {
  constructor(categories) {
    super(categories);
    this.name = 'Unread';
    this.iconName = 'unread.png';
  }

  threads() {
    return new UnreadQuerySubscription(this.categories().map(c => c.id));
  }

  unreadCount() {
    return 0;
  }

  actionsForReceivingThreads(threads, accountId) {
    ChangeUnreadTask = ChangeUnreadTask || require('./flux/tasks/change-unread-task').default;
    const tasks = super.actionsForReceivingThreads(threads, accountId);
    tasks.push(
      new ChangeUnreadTask({
        threads: threads,
        unread: true,
        source: 'Dragged Into List',
      })
    );
    return tasks;
  }

  tasksForRemovingItems(threads, ruleset, source) {
    ChangeUnreadTask = ChangeUnreadTask || require('./flux/tasks/change-unread-task').default;

    const tasks = super.tasksForRemovingItems(threads, ruleset, source);
    tasks.push(
      new ChangeUnreadTask({ threads, unread: false, source: source || 'Removed From List' })
    );
    return tasks;
  }
}
