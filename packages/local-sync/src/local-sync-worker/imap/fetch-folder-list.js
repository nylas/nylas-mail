const crypto = require('crypto')
const {Provider, PromiseUtils} = require('isomorphic-core');
const {localizedCategoryNames} = require('../sync-utils')

const BASE_ROLES = ['inbox', 'sent', 'trash', 'spam'];
const GMAIL_ROLES_WITH_FOLDERS = ['all', 'trash', 'spam'];

class FetchFolderList {
  constructor(provider, logger) {
    this._provider = provider;
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
        '\\Flagged': 'flagged',
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
      stack.push([boxName, boxes[boxName]]);
    });

    while (stack.length > 0) {
      const [boxName, box] = stack.pop();
      if (!box.attribs) {
        // Some boxes seem to come back as partial objects. Not sure why, but
        // I also can't access them via openMailbox. Possible node-imap i8n issue?
        continue;
      }

      this._logger.info({
        box_name: boxName,
        attributes: JSON.stringify(box.attribs),
      }, `FetchFolderList: Box Information`)


      if (box.children && box.attribs.includes('\\HasChildren')) {
        Object.keys(box.children).forEach((subname) => {
          stack.push([`${boxName}${box.delimiter}${subname}`, box.children[subname]]);
        });
      }

      let category = categories.find((cat) => cat.name === boxName);
      if (!category) {
        const role = this._roleByAttr(box);
        const Klass = this._classForMailboxWithRole(role, this._db);
        category = Klass.build({
          id: crypto.createHash('sha256').update(boxName, 'utf8').digest('hex'),
          name: boxName,
          accountId: this._db.accountId,
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

  async run(db, imap) {
    this._db = db;

    const boxes = await imap.getBoxes();
    const {Folder, Label, sequelize} = this._db;

    return sequelize.transaction(async (transaction) => {
      const {folders, labels} = await PromiseUtils.props({
        folders: Folder.findAll({transaction}),
        labels: Label.findAll({transaction}),
      })
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

      let promises = [Promise.resolve()]
      promises = promises.concat(created.map(cat => cat.save({transaction})))
      promises = promises.concat(deleted.map(cat => cat.destroy({transaction})))
      return Promise.all(promises)
    });
  }
}

module.exports = FetchFolderList;
