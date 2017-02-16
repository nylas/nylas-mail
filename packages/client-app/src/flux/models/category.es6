/* eslint global-require: 0 */
import {NylasSyncStatusStore} from 'nylas-exports';
import Model from './model';
import Attributes from '../attributes';
let AccountStore = null

// We look for a few standard categories and display them in the Mailboxes
// portion of the left sidebar. Note that these may not all be present on
// a particular account.
const ToObject = (arr) => {
  return arr.reduce((o, v) => {
    o[v] = v;
    return o;
  }, {});
}

const StandardCategories = ToObject([
  "inbox",
  "important",
  "sent",
  "drafts",
  "all",
  "spam",
  "archive",
  "trash",
]);

const LockedCategories = ToObject([
  "sent",
  "drafts",
  "N1-Snoozed",
]);

const HiddenCategories = ToObject([
  "sent",
  "drafts",
  "all",
  "archive",
  "starred",
  "important",
  "N1-Snoozed",
]);

/**
Private:
This abstract class has only two concrete implementations:
  - `Folder`
  - `Label`

See the equivalent models for details.

Folders and Labels have different semantics. The `Category` class only exists to help DRY code where they happen to behave the same

## Attributes

`name`: {AttributeString} The internal name of the label or folder. Queryable.

`displayName`: {AttributeString} The display-friendly name of the label or folder. Queryable.

Section: Models
*/
export default class Category extends Model {

  static attributes = Object.assign({}, Model.attributes, {
    name: Attributes.String({
      queryable: true,
      modelKey: 'name',
    }),
    displayName: Attributes.String({
      queryable: true,
      modelKey: 'displayName',
      jsonKey: 'display_name',
    }),
    imapName: Attributes.String({
      modelKey: 'imapName',
      jsonKey: 'imap_name',
    }),
    syncProgress: Attributes.Object({
      modelKey: 'syncProgress',
      jsonKey: 'sync_progress',
    }),
  });

  static Types = {
    Standard: 'standard',
    Locked: 'locked',
    User: 'user',
    Hidden: 'hidden',
  }

  static StandardCategoryNames = Object.keys(StandardCategories)
  static LockedCategoryNames = Object.keys(LockedCategories)
  static HiddenCategoryNames = Object.keys(HiddenCategories)

  static categoriesSharedName(cats) {
    if (!cats || cats.length === 0) {
      return null;
    }
    const name = cats[0].name
    if (!cats.every((cat) => cat.name === name)) {
      return null;
    }
    return name;
  }

  static additionalSQLiteConfig = {
    setup: () => {
      return [
        'CREATE INDEX IF NOT EXISTS CategoryNameIndex ON Category(account_id,name)',
        'CREATE UNIQUE INDEX IF NOT EXISTS CategoryClientIndex ON Category(client_id)',
      ];
    },
  };

  fromJSON(json) {
    super.fromJSON(json);

    if (this.displayName && this.displayName.startsWith('INBOX.')) {
      this.displayName = this.displayName.substr(6);
    }
    if (this.displayName && this.displayName === 'INBOX') {
      this.displayName = 'Inbox';
    }
    return this;
  }

  displayType() {
    AccountStore = AccountStore || require('../stores/account-store').default;
    if (AccountStore.accountForId(this.accountId).usesLabels()) {
      return 'label';
    }
    return 'folder';
  }

  hue() {
    if (!this.displayName) {
      return 0;
    }

    let hue = 0;
    for (let i = 0; i < this.displayName.length; i++) {
      hue += this.displayName.charCodeAt(i);
    }
    hue *= (396.0 / 512.0);
    return hue;
  }

  isStandardCategory(forceShowImportant) {
    let showImportant = forceShowImportant;
    if (showImportant === undefined) {
      showImportant = NylasEnv.config.get('core.workspace.showImportant');
    }
    if (showImportant === true) {
      return !!StandardCategories[this.name];
    }
    return !!StandardCategories[this.name] && (this.name !== 'important');
  }

  isLockedCategory() {
    return !!LockedCategories[this.name] || !!LockedCategories[this.displayName];
  }

  isHiddenCategory() {
    return !!HiddenCategories[this.name] || !!HiddenCategories[this.displayName];
  }

  isUserCategory() {
    return !this.isStandardCategory() && !this.isHiddenCategory();
  }

  isArchive() {
    return ['all', 'archive'].includes(this.name);
  }

  isSyncComplete() {
    // We sync by folders, not labels. If the category is a label, or hasn't been
    // assigned an object type yet, just return based on the sync status for the
    // entire account.
    if (this.object !== 'folder') {
      return NylasSyncStatusStore.isSyncCompleteForAccount(this.accountId);
    }
    return NylasSyncStatusStore.isSyncCompleteForAccount(
      this.accountId,
      this.name || this.displayName
    );
  }
}
