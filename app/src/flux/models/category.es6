/* eslint global-require: 0 */
import Model from './model';
import Attributes from '../attributes';

// We look for a few standard categories and display them in the Mailboxes
// portion of the left sidebar. Note that these may not all be present on
// a particular account.
const ToObject = arr => {
  return arr.reduce((o, v) => {
    o[v] = v;
    return o;
  }, {});
};

const StandardRoleMap = ToObject([
  'inbox',
  'important',
  'snoozed',
  'sent',
  'drafts',
  'all',
  'spam',
  'archive',
  'trash',
]);

const LockedRoleMap = ToObject(['sent', 'drafts']);

const HiddenRoleMap = ToObject([
  'sent',
  'drafts',
  'all',
  'archive',
  'starred',
  'important',
  'snoozed',
  '[Mailspring]',
]);

/**
Private:
This abstract class has only two concrete implementations:
  - `Folder`
  - `Label`

See the equivalent models for details.

Folders and Labels have different semantics. The `Category` class only exists to help DRY code where they happen to behave the same

## Attributes

`role`: {AttributeString} The internal role of the label or folder. Queryable.

`path`: {AttributeString} The IMAP path name of the label or folder. Queryable.

Section: Models
*/
export default class Category extends Model {
  get displayName() {
    for (const prefix of ['INBOX', '[Gmail]', '[Mailspring]']) {
      if (this.path.startsWith(prefix) && this.path.length > prefix.length + 1) {
        return this.path.substr(prefix.length + 1); // + delimiter
      }
    }
    if (this.path === 'INBOX') {
      return 'Inbox';
    }
    return this.path;
  }

  /* Available for historical reasons, do not use. */
  get name() {
    return this.role;
  }

  static attributes = Object.assign({}, Model.attributes, {
    role: Attributes.String({
      queryable: true,
      modelKey: 'role',
    }),
    path: Attributes.String({
      queryable: true,
      modelKey: 'path',
    }),
    localStatus: Attributes.Object({
      modelKey: 'localStatus',
    }),
  });

  static Types = {
    Standard: 'standard',
    Locked: 'locked',
    User: 'user',
    Hidden: 'hidden',
  };

  static StandardRoles = Object.keys(StandardRoleMap);
  static LockedRoles = Object.keys(LockedRoleMap);
  static HiddenRoles = Object.keys(HiddenRoleMap);

  static categoriesSharedRole(cats) {
    if (!cats || cats.length === 0) {
      return null;
    }
    const role = cats[0].role;
    if (!cats.every(cat => cat.role === role)) {
      return null;
    }
    return role;
  }

  displayType() {
    throw new Error('Base class');
  }

  hue() {
    if (!this.displayName) {
      return 0;
    }

    let hue = 0;
    for (let i = 0; i < this.displayName.length; i++) {
      hue += this.displayName.charCodeAt(i);
    }
    hue *= 396.0 / 512.0;
    return hue;
  }

  isStandardCategory(forceShowImportant) {
    let showImportant = forceShowImportant;
    if (showImportant === undefined) {
      showImportant = AppEnv.config.get('core.workspace.showImportant');
    }
    if (showImportant === true) {
      return !!StandardRoleMap[this.role];
    }
    return !!StandardRoleMap[this.role] && this.role !== 'important';
  }

  isLockedCategory() {
    return !!LockedRoleMap[this.role] || !!LockedRoleMap[this.path];
  }

  isHiddenCategory() {
    return !!HiddenRoleMap[this.role] || !!HiddenRoleMap[this.path];
  }

  isUserCategory() {
    return !this.isStandardCategory() && !this.isHiddenCategory();
  }

  isArchive() {
    return ['all', 'archive'].includes(this.role);
  }
}
