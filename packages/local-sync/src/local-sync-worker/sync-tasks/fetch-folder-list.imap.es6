const {Provider} = require('isomorphic-core');
const SyncTask = require('./sync-task')
const {localizedCategoryNames} = require('../sync-utils')


const GMAIL_ROLES_WITH_FOLDERS = ['all', 'trash', 'spam'];

class FetchFolderListIMAP extends SyncTask {
  constructor(...args) {
    super(...args)
    this._provider = this._account.provider;
  }

  description() {
    return `FetchFolderListIMAP`;
  }

  _classForMailboxWithRole(role, {Folder, Label}) {
    if (this._provider === Provider.Gmail) {
      return GMAIL_ROLES_WITH_FOLDERS.includes(role) ? Folder : Label;
    }
    return Folder;
  }

  _detectRole(boxName, box) {
    return this._roleByAttr(box) || this._roleByName(boxName);
  }

  _roleByName(boxName) {
    for (const role of Object.keys(localizedCategoryNames)) {
      if (localizedCategoryNames[role].has(boxName.toLowerCase().trim())) {
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

  async _updateCategoriesWithBoxes(categories, boxes) {
    const stack = [];
    const created = [];
    const existing = new Set();

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
        const role = this._detectRole(boxName, box);
        const Klass = this._classForMailboxWithRole(role, this._db);
        const {accountId} = this._db
        category = Klass.build({
          accountId,
          id: Klass.hash({boxName, accountId}),
          name: boxName,
          role: role,
        });
        created.push(category);
      } else if (!category.role) {
        // if we update the category->role mapping to include more names, we
        // need to be able to detect newly added roles on existing categories
        const role = this._roleByName(boxName);
        if (role) {
          category.role = role;
          await category.save();
        }
      }
      existing.add(category);
    }

    // TODO: decide whether these are renames or deletes
    const deleted = categories.filter(cat => !existing.has(cat));

    for (const category of created) {
      await category.save()
    }

    for (const category of deleted) {
      await category.destroy()
    }
  }

  // This operation is interruptible, see `SyncTask` for info on why we use
  // `yield`
  async * runTask(db, imap) {
    this._logger.log(`🔜  Fetching folder list`)
    this._db = db;

    const boxes = yield imap.getBoxes();
    const {Folder, Label} = this._db;

    const folders = yield Folder.findAll()
    const labels = yield Label.findAll()
    const all = [].concat(folders, labels);
    await this._updateCategoriesWithBoxes(all, boxes);

    this._logger.log(`🔚  Fetching folder list done`)
  }
}

module.exports = FetchFolderListIMAP;
