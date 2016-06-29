const {Provider} = require('nylas-core');

const GMAIL_FOLDERS = ['[Gmail]/All Mail', '[Gmail]/Trash', '[Gmail]/Spam'];

class FetchCategoryList {
  constructor(provider) {
    this._provider = provider;
  }

  description() {
    return `FetchCategoryList`;
  }

  _typeForMailbox(boxName) {
    if (this._provider === Provider.Gmail) {
      return GMAIL_FOLDERS.includes(boxName) ? 'folder' : 'label';
    }
    return 'folder';
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
    const {Category} = this._db;

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
        category = Category.build({
          name: boxName,
          accountId: this._db.accountId,
          type: this._typeForMailbox(boxName, box),
          role: this._roleForMailbox(boxName, box),
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
      const {Category, sequelize} = this._db;

      return sequelize.transaction((transaction) => {
        return Category.findAll({transaction}).then((categories) => {
          const {created, deleted} = this._updateCategoriesWithBoxes(categories, boxes);

          let promises = [Promise.resolve()]
          promises = promises.concat(created.map(cat => cat.save({transaction})))
          promises = promises.concat(deleted.map(cat => cat.destroy({transaction})))
          return Promise.all(promises)
        });
      });
    });
  }
}

module.exports = FetchCategoryList;
