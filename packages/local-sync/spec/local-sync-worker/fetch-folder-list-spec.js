const {PromiseUtils} = require('isomorphic-core');
const mockDatabase = require('./mock-database');
const FetchFolderList = require('../../src/local-sync-worker/imap/fetch-folder-list')

const testCategoryRoles = (db, mailboxes) => {
  const mockLogger = {
    info: () => {},
    debug: () => {},
    error: () => {},
  }
  const mockImap = {
    getBoxes: () => {
      return Promise.resolve(mailboxes)
    },
  }
  return new FetchFolderList('fakeProvider', mockLogger).run(db, mockImap).then(() => {
    const {Folder, Label} = db;
    return PromiseUtils.props({
      folders: Folder.findAll(),
      labels: Label.findAll(),
    }).then(({folders, labels}) => {
      const all = [].concat(folders, labels);
      for (const category of all) {
        expect(category.role).toEqual(mailboxes[category.name].role);
      }
    })
  })
};

describe("FetchFolderList", () => {
  beforeEach((done) => {
    mockDatabase().then((db) => {
      this.db = db;
      done();
    })
  })

  it("assigns roles when given a role attribute/flag", (done) => {
    const mailboxes = {
      'Sent': {attribs: ['\\Sent'], role: 'sent'},
      'Drafts': {attribs: ['\\Drafts'], role: 'drafts'},
      'Spam': {attribs: ['\\Spam'], role: 'spam'},
      'Trash': {attribs: ['\\Trash'], role: 'trash'},
      'All Mail': {attribs: ['\\All'], role: 'all'},
      'Important': {attribs: ['\\Important'], role: 'important'},
      'Flagged': {attribs: ['\\Flagged'], role: 'flagged'},
      'Inbox': {attribs: ['\\Inbox'], role: 'inbox'},
      'TestFolder': {attribs: [], role: null},
      'Receipts': {attribs: [], role: null},
    }

    testCategoryRoles(this.db, mailboxes).then(done, done.fail);
  })

  it("assigns missing roles by localized display names", (done) => {
    const mailboxes = {
      'Sent': {attribs: [], role: 'sent'},
      'Drafts': {attribs: ['\\Drafts'], role: 'drafts'},
      'Spam': {attribs: ['\\Spam'], role: 'spam'},
      'Trash': {attribs: ['\\Trash'], role: 'trash'},
      'All Mail': {attribs: ['\\All'], role: 'all'},
      'Important': {attribs: ['\\Important'], role: 'important'},
      'Flagged': {attribs: ['\\Flagged'], role: 'flagged'},
      'Inbox': {attribs: [], role: 'inbox'},
    }

    testCategoryRoles(this.db, mailboxes).then(done, done.fail);
  })

  it("doesn't assign a role more than once", (done) => {
    const mailboxes = {
      'Sent': {attribs: [], role: null},
      'Sent Items': {attribs: [], role: null},
      'Drafts': {attribs: ['\\Drafts'], role: 'drafts'},
      'Spam': {attribs: ['\\Spam'], role: 'spam'},
      'Trash': {attribs: ['\\Trash'], role: 'trash'},
      'All Mail': {attribs: ['\\All'], role: 'all'},
      'Important': {attribs: ['\\Important'], role: 'important'},
      'Flagged': {attribs: ['\\Flagged'], role: 'flagged'},
      'Mail': {attribs: ['\\Inbox'], role: 'inbox'},
      'inbox': {attribs: [], role: null},
    }

    testCategoryRoles(this.db, mailboxes).then(done, done.fail);
  })

  it("updates role assignments if an assigned category is deleted", (done) => {
    let mailboxes = {
      'Sent': {attribs: [], role: null},
      'Sent Items': {attribs: [], role: null},
      'Drafts': {attribs: ['\\Drafts'], role: 'drafts'},
      'Spam': {attribs: ['\\Spam'], role: 'spam'},
      'Trash': {attribs: ['\\Trash'], role: 'trash'},
      'All Mail': {attribs: ['\\All'], role: 'all'},
      'Important': {attribs: ['\\Important'], role: 'important'},
      'Flagged': {attribs: ['\\Flagged'], role: 'flagged'},
      'Mail': {attribs: ['\\Inbox'], role: 'inbox'},
    }

    testCategoryRoles(this.db, mailboxes).then(() => {
      mailboxes = {
        'Sent Items': {attribs: [], role: 'sent'},
        'Drafts': {attribs: ['\\Drafts'], role: 'drafts'},
        'Spam': {attribs: ['\\Spam'], role: 'spam'},
        'Trash': {attribs: ['\\Trash'], role: 'trash'},
        'All Mail': {attribs: ['\\All'], role: 'all'},
        'Important': {attribs: ['\\Important'], role: 'important'},
        'Flagged': {attribs: ['\\Flagged'], role: 'flagged'},
        'Mail': {attribs: ['\\Inbox'], role: 'inbox'},
      }

      return testCategoryRoles(this.db, mailboxes).then(done, done.fail);
    }, done.fail);
  })
});
