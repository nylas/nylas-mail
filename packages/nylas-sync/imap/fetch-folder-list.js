const {Provider} = require('nylas-core');

const GMAIL_ROLES_WITH_FOLDERS = ['all', 'trash', 'junk'];

class FetchFolderList {
  constructor(provider, logger = console) {
    this._provider = provider;
    this._logger = logger;
  }

  description() {
    return `FetchFolderList`;
  }

  _classForMailboxWithRole(role, {Folder, Label}) {
    if (this._provider === Provider.Gmail) {
      return GMAIL_ROLES_WITH_FOLDERS.includes(role) ? Folder : Label;
    }
    return Folder;
  }

  _roleForMailbox(boxName, box) {
    for (const attrib of (box.attribs || [])) {
      const role = {
        '\\Sent': 'sent',
        '\\Drafts': 'drafts',
        '\\Junk': 'junk',
        '\\Trash': 'trash',
        '\\All': 'all',
        '\\Important': 'important',
        '\\Flagged': 'flagged',
      }[attrib];
      if (role) {
        return role;
      }
    }
    if (boxName.toLowerCase().trim() === 'inbox') {
      return 'inbox';
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

      if (box.children && box.attribs.includes('\\HasChildren')) {
        Object.keys(box.children).forEach((subname) => {
          stack.push([`${boxName}${box.delimiter}${subname}`, box.children[subname]]);
        });
      }

      let category = categories.find((cat) => cat.name === boxName);
      if (!category) {
        const role = this._roleForMailbox(boxName, box);
        const Klass = this._classForMailboxWithRole(role, this._db);
        category = Klass.build({
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

  run(db, imap) {
    this._db = db;

    return imap.getBoxes().then((boxes) => {
      const {Folder, Label, sequelize} = this._db;

      return sequelize.transaction((transaction) => {
        return Promise.props({
          folders: Folder.findAll({transaction}),
          labels: Label.findAll({transaction}),
        }).then(({folders, labels}) => {
          const all = [].concat(folders, labels);
          const {created, deleted} = this._updateCategoriesWithBoxes(all, boxes);

          let promises = [Promise.resolve()]
          promises = promises.concat(created.map(cat => cat.save({transaction})))
          promises = promises.concat(deleted.map(cat => cat.destroy({transaction})))
          return Promise.all(promises)
        });
      });
    });
  }
}

module.exports = FetchFolderList;
