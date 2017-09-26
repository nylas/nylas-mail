import _ from 'underscore';
import { Categories } from 'mailspring-observables';
import MailspringStore from 'mailspring-store';
import AccountStore from './account-store';
import Account from '../models/account';
import Category from '../models/category';

const asAccount = a => {
  if (!a) {
    throw new Error('You must pass an Account or Account Id');
  }
  return a instanceof Account ? a : AccountStore.accountForId(a);
};

const asAccountId = a => {
  if (!a) {
    throw new Error('You must pass an Account or Account Id');
  }
  return a instanceof Account ? a.id : a;
};

class CategoryStore extends MailspringStore {
  constructor() {
    super();
    this._categoryCache = {};
    this._standardCategories = {};
    this._userCategories = {};
    this._hiddenCategories = {};

    AppEnv.config.onDidChange('core.workspace.showImportant', () => {
      if (this._categoryResult) {
        this._onCategoriesChanged(this._categoryResult);
      }
    });

    Categories.forAllAccounts()
      .sort()
      .subscribe(this._onCategoriesChanged);
  }

  byId(accountOrId, categoryId) {
    const categories = this._categoryCache[asAccountId(accountOrId)] || {};
    return categories[categoryId];
  }

  // Public: Returns an array of all categories for an account, both
  // standard and user generated. The items returned by this function will be
  // either {Folder} or {Label} objects.
  //
  categories(accountOrId = null) {
    if (accountOrId) {
      const cached = this._categoryCache[asAccountId(accountOrId)];
      return cached ? Object.values(cached) : [];
    }
    let all = [];
    for (const accountCategories of Object.values(this._categoryCache)) {
      all = all.concat(Object.values(accountCategories));
    }
    return all;
  }

  // Public: Returns all of the standard categories for the given account.
  //
  standardCategories(accountOrId) {
    return this._standardCategories[asAccountId(accountOrId)] || [];
  }

  hiddenCategories(accountOrId) {
    return this._hiddenCategories[asAccountId(accountOrId)] || [];
  }

  // Public: Returns all of the categories that are not part of the standard
  // category set.
  //
  userCategories(accountOrId) {
    return this._userCategories[asAccountId(accountOrId)] || [];
  }

  // Public: Returns the Folder or Label object for a standard category name and
  // for a given account.
  // ('inbox', 'drafts', etc.) It's possible for this to return `null`.
  // For example, Gmail likely doesn't have an `archive` label.
  //
  getCategoryByRole(accountOrId, role) {
    if (!accountOrId) {
      return null;
    }

    if (!Category.StandardRoles.includes(role)) {
      throw new Error(`'${role}' is not a standard category`);
    }

    const accountCategories = this._standardCategories[asAccountId(accountOrId)];
    return (accountCategories && accountCategories.find(c => c.role === role)) || null;
  }

  // Public: Returns the set of all standard categories that match the given
  // names for each of the provided accounts
  getCategoriesWithRoles(accountsOrIds, ...names) {
    if (Array.isArray(accountsOrIds)) {
      let res = [];
      for (const accOrId of accountsOrIds) {
        const cats = names.map(name => this.getCategoryByRole(accOrId, name));
        res = res.concat(_.compact(cats));
      }
      return res;
    }
    return _.compact(names.map(name => this.getCategoryByRole(accountsOrIds, name)));
  }

  // Public: Returns the Folder or Label object that should be used for "Archive"
  // actions. On Gmail, this is the "all" label. On providers using folders, it
  // returns any available "Archive" folder, or null if no such folder exists.
  //
  getArchiveCategory(accountOrId) {
    if (!accountOrId) {
      return null;
    }
    const account = asAccount(accountOrId);
    if (!account) {
      return null;
    }

    return (
      this.getCategoryByRole(account.id, 'archive') || this.getCategoryByRole(account.id, 'all')
    );
  }

  // Public: Returns Label object for "All mail"
  //
  getAllMailCategory(accountOrId) {
    if (!accountOrId) {
      return null;
    }
    const account = asAccount(accountOrId);
    if (!account) {
      return null;
    }

    return this.getCategoryByRole(account.id, 'all');
  }

  // Public: Returns the Folder or Label object that should be used for
  // the inbox or null if it doesn't exist
  //
  getInboxCategory(accountOrId) {
    return this.getCategoryByRole(accountOrId, 'inbox');
  }

  // Public: Returns the Folder or Label object that should be used for
  // "Move to Trash", or null if no trash folder exists.
  //
  getTrashCategory(accountOrId) {
    return this.getCategoryByRole(accountOrId, 'trash');
  }

  // Public: Returns the Folder or Label object that should be used for
  // "Move to Spam", or null if no trash folder exists.
  //
  getSpamCategory(accountOrId) {
    return this.getCategoryByRole(accountOrId, 'spam');
  }

  _onCategoriesChanged = categories => {
    this._categoryResult = categories;
    this._categoryCache = {};
    for (const cat of categories) {
      this._categoryCache[cat.accountId] = this._categoryCache[cat.accountId] || {};
      this._categoryCache[cat.accountId][cat.id] = cat;
    }

    const filteredByAccount = fn => {
      const result = {};
      for (const cat of categories) {
        if (!fn(cat)) {
          continue;
        }
        result[cat.accountId] = result[cat.accountId] || [];
        result[cat.accountId].push(cat);
      }
      return result;
    };

    this._standardCategories = filteredByAccount(cat => cat.isStandardCategory());
    this._userCategories = filteredByAccount(cat => cat.isUserCategory());
    this._hiddenCategories = filteredByAccount(cat => cat.isHiddenCategory());

    // Ensure standard categories are always sorted in the correct order
    for (const accountCategories of Object.values(this._standardCategories)) {
      accountCategories.sort(
        (a, b) => Category.StandardRoles.indexOf(a.name) - Category.StandardRoles.indexOf(b.name)
      );
    }
    this.trigger();
  };
}

export default new CategoryStore();
