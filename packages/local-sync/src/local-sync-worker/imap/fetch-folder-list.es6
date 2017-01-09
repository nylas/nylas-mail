const {Provider} = require('isomorphic-core');
const SyncOperation = require('../sync-operation')
const {localizedCategoryNames} = require('../sync-utils')


const BASE_ROLES = ['inbox', 'archive', 'sent', 'trash', 'spam'];
const GMAIL_ROLES_WITH_FOLDERS = ['all', 'trash', 'spam'];

class FetchFolderList extends SyncOperation {
  constructor(account, logger) {
    super()
    this._account = account;
    this._provider = account.provider;
    this._logger = logger;
    if (!this._logger) {
      throw new Error("FetchFolderList requires a logger")
    }
  }

  description() {
    return `FetchFolderList`;
  }

  _getMissingRoles(categories) {
    const currentRoles = new Set(categories.map(cat => cat.role));
    const missingRoles = BASE_ROLES.filter(role => !currentRoles.has(role));
    return missingRoles;
  }

  _classForMailboxWithRole(role, {Folder, Label}) {
    if (this._provider === Provider.Gmail) {
      return GMAIL_ROLES_WITH_FOLDERS.includes(role) ? Folder : Label;
    }
    return Folder;
  }

  _roleByName(boxName) {
    for (const role of Object.keys(localizedCategoryNames)) {
      if (localizedCategoryNames[role].includes(boxName.toLowerCase().trim())) {
        return role;
      }
    }
    return null;
  }

  _roleByAttr(box) {
    for (const attrib of (box.attribs || [])) {
      const role = {
        '\\Sent': 'sent',
        '\\Drafts': 'drafts',
        '\\Junk': 'spam',
        '\\Spam': 'spam',
        '\\Trash': 'trash',
        '\\All': 'all',
        '\\Important': 'important',
        '\\Flagged': 'starred',
        '\\Inbox': 'inbox',
      }[attrib];
      if (role) {
        return role;
      }
    }
    return null;
  }

  _updateCategoriesWithBoxes(categories, boxes) {
    const stack = [];
    const created = [];
    const next = [];

    Object.keys(boxes).forEach((boxName) => {
      stack.push([[boxName], boxes[boxName]]);
    });

    while (stack.length > 0) {
      const [boxPath, box] = stack.pop();

      if (!box.attribs) {
        if (box.children) {
          // In Fastmail, folders which are just containers for other folders
          // have no attributes at all, just a children property. Add appropriate
          // attribs so we can carry on.
          box.attribs = ['\\HasChildren', '\\NoSelect'];
        } else {
          // Some boxes seem to come back as partial objects. Not sure why.
          continue;
        }
      }

      const boxName = boxPath.join(box.delimiter);

      // this._logger.info({
      //   box_name: boxName,
      //   attributes: JSON.stringify(box.attribs),
      // }, `FetchFolderList: Box Information`)


      if (box.children && box.attribs.includes('\\HasChildren')) {
        Object.keys(box.children).forEach((subname) => {
          stack.push([[].concat(boxPath, [subname]), box.children[subname]]);
        });
      }

      const lowerCaseAttrs = box.attribs.map(attr => attr.toLowerCase())
      if (lowerCaseAttrs.includes('\\noselect') || lowerCaseAttrs.includes('\\nonexistent')) {
        continue;
      }

      let category = categories.find((cat) => cat.name === boxName);
      if (!category) {
        const role = this._roleByAttr(box);
        const Klass = this._classForMailboxWithRole(role, this._db);
        const {accountId} = this._db
        category = Klass.build({
          accountId,
          id: Klass.hash({boxName, accountId}),
          name: boxName,
          role: role,
        });
        created.push(category);
      }
      next.push(category);
    }

    // Todo: decide whether these are renames or deletes
    const deleted = categories.filter(cat => !next.includes(cat));

    return {next, created, deleted};
  }

  // This operation is interruptible, see `SyncOperation` for info on why we use
  // `yield`
  async * runOperation(db, imap) {
    console.log(`🔃  Fetching folder list`)
    this._db = db;

    const boxes = yield imap.getBoxes();
    const {Folder, Label} = this._db;

    const folders = yield Folder.findAll()
    const labels = yield Label.findAll()
    const all = [].concat(folders, labels);
    const {next, created, deleted} = this._updateCategoriesWithBoxes(all, boxes);

    const categoriesByRoles = next.reduce((obj, cat) => {
      const role = this._roleByName(cat.name);
      if (role in obj) {
        obj[role].push(cat);
      } else {
        obj[role] = [cat];
      }
      return obj;
    }, {})

    this._getMissingRoles(next).forEach((role) => {
      if (categoriesByRoles[role] && categoriesByRoles[role].length === 1) {
        categoriesByRoles[role][0].role = role;
      }
    })

    for (const category of created) {
      await category.save()
    }

    for (const category of deleted) {
      await category.destroy()
    }
  }
}

module.exports = FetchFolderList;
