import _ from 'underscore';
import MailspringStore from 'mailspring-store';
import AccountStore from './account-store';
import WorkspaceStore from './workspace-store';
import MailboxPerspective from '../../mailbox-perspective';
import CategoryStore from './category-store';
import Actions from '../actions';

class FocusedPerspectiveStore extends MailspringStore {
  constructor() {
    super();
    this._current = MailboxPerspective.forNothing();
    this._initialized = false;

    this.listenTo(CategoryStore, this._onCategoryStoreChanged);
    this.listenTo(Actions.focusMailboxPerspective, this._onFocusPerspective);
    this.listenTo(
      Actions.focusDefaultMailboxPerspectiveForAccounts,
      this._onFocusDefaultPerspectiveForAccounts
    );
    this.listenTo(Actions.ensureCategoryIsFocused, this._onEnsureCategoryIsFocused);
    this._listenToCommands();
  }

  current() {
    return this._current;
  }

  sidebarAccountIds() {
    let ids = AppEnv.savedState.sidebarAccountIds;
    if (!ids || !ids.length || !ids.every(id => AccountStore.accountForId(id))) {
      ids = AppEnv.savedState.sidebarAccountIds = AccountStore.accountIds();
    }

    // Always defer to the AccountStore for the desired order of accounts in
    // the sidebar - users can re-arrange them!
    const order = AccountStore.accountIds();
    ids = ids.sort((a, b) => order.indexOf(a) - order.indexOf(b));

    return ids;
  }

  _listenToCommands() {
    AppEnv.commands.add(document.body, {
      'navigation:go-to-inbox': () => this._setPerspectiveByName('inbox'),
      'navigation:go-to-sent': () => this._setPerspectiveByName('sent'),
      'navigation:go-to-starred': () =>
        this._setPerspective(MailboxPerspective.forStarred(this._current.accountIds)),
      'navigation:go-to-drafts': () =>
        this._setPerspective(MailboxPerspective.forDrafts(this._current.accountIds)),
      'navigation:go-to-all': () => {
        const categories = this._current.accountIds.map(id => CategoryStore.getArchiveCategory(id));
        this._setPerspective(MailboxPerspective.forCategories(categories));
      },
      'navigation:go-to-contacts': () => {}, // TODO,
      'navigation:go-to-tasks': () => {}, // TODO,
      'navigation:go-to-label': () => {}, // TODO,
    });
  }

  _isValidAccountSet(ids) {
    const accountIds = AccountStore.accountIds();
    return ids.every(a => accountIds.includes(a));
  }

  _isValidPerspective(perspective) {
    // Ensure all the accountIds referenced in the perspective still exist
    if (!this._isValidAccountSet(perspective.accountIds)) {
      return false;
    }

    // Ensure all the categories referenced in the perspective still exist
    const categoriesStillExist = perspective.categories().every(c => {
      return !!CategoryStore.byId(c.accountId, c.id);
    });
    if (!categoriesStillExist) {
      return false;
    }

    return true;
  }

  _initializeFromSavedState() {
    const json = AppEnv.savedState.perspective;
    let { sidebarAccountIds } = AppEnv.savedState;
    let perspective;

    if (json) {
      perspective = MailboxPerspective.fromJSON(json);
    }
    this._initialized = true;

    if (!perspective || !this._isValidPerspective(perspective)) {
      perspective = this._defaultPerspective();
      sidebarAccountIds = perspective.accountIds;
      this._initialized = false;
    }

    if (
      !sidebarAccountIds ||
      !this._isValidAccountSet(sidebarAccountIds) ||
      sidebarAccountIds.length < perspective.accountIds.length
    ) {
      sidebarAccountIds = perspective.accountIds;
      this._initialized = false;
    }

    this._setPerspective(perspective, sidebarAccountIds);
  }

  // Inbound Events
  _onCategoryStoreChanged = () => {
    if (!this._initialized) {
      this._initializeFromSavedState();
    } else if (!this._isValidPerspective(this._current)) {
      this._setPerspective(this._defaultPerspective(this._current.accountIds));
    }
  };

  _onFocusPerspective = perspective => {
    // If looking at unified inbox, don't attempt to change the sidebar accounts
    const sidebarIsUnifiedInbox = this.sidebarAccountIds().length > 1;
    if (sidebarIsUnifiedInbox) {
      this._setPerspective(perspective);
    } else {
      this._setPerspective(perspective, perspective.accountIds);
    }
  };

  /*
  * Takes an optional array of `sidebarAccountIds`. By default, this method will
  * set the sidebarAccountIds to the perspective's accounts if no value is
  * provided
  */
  _onFocusDefaultPerspectiveForAccounts = (accountsOrIds, { sidebarAccountIds } = {}) => {
    if (!accountsOrIds) {
      return;
    }
    const perspective = this._defaultPerspective(accountsOrIds);
    this._setPerspective(perspective, sidebarAccountIds || perspective.accountIds);
  };

  _onEnsureCategoryIsFocused = (categoryName, accountIds = []) => {
    const ids = accountIds instanceof Array ? accountIds : [accountIds];
    const categories = ids.map(id => CategoryStore.getCategoryByRole(id, categoryName));
    const perspective = MailboxPerspective.forCategories(categories);
    this._onFocusPerspective(perspective);
  };

  _defaultPerspective(accountsOrIds = AccountStore.accountIds()) {
    const perspective = MailboxPerspective.forInbox(accountsOrIds);

    // If no account ids were selected, or the categories for these accounts have
    // not loaded yet, return forNothing(). This means that the next time the
    // CategoryStore triggers, we'll try again.
    if (perspective.categories().length === 0) {
      return MailboxPerspective.forNothing();
    }
    return perspective;
  }

  _setPerspective(perspective, sidebarAccountIds) {
    let shouldTrigger = false;

    if (!perspective.isEqual(this._current)) {
      AppEnv.savedState.perspective = perspective.toJSON();
      this._current = perspective;
      shouldTrigger = true;
    }

    const shouldSaveSidebarAccountIds =
      sidebarAccountIds &&
      !_.isEqual(AppEnv.savedState.sidebarAccountIds, sidebarAccountIds) &&
      this._initialized === true;
    if (shouldSaveSidebarAccountIds) {
      AppEnv.savedState.sidebarAccountIds = sidebarAccountIds;
      shouldTrigger = true;
    }

    if (shouldTrigger) {
      this.trigger();
    }

    let desired = perspective.sheet();

    // Always switch to the correct sheet and pop to root when perspective set
    if (desired && WorkspaceStore.rootSheet() !== desired) {
      Actions.selectRootSheet(desired);
    }
    Actions.popToRootSheet();
  }

  _setPerspectiveByName(categoryName) {
    let categories = this._current.accountIds.map(id => {
      return CategoryStore.getCategoryByRole(id, categoryName);
    });
    categories = _.compact(categories);
    if (categories.length === 0) {
      return;
    }
    this._setPerspective(MailboxPerspective.forCategories(categories));
  }
}

export default new FocusedPerspectiveStore();
