const IMAPConnection = require('./imap/connection');
const RefreshMailboxesOperation = require('./imap/refresh-mailboxes-operation')
const SyncMailboxOperation = require('./imap/sync-mailbox-operation')

class SyncWorker {
  constructor(account, db) {
    const main = new IMAPConnection(db, {
      user: 'inboxapptest1@fastmail.fm',
      password: 'trar2e',
      host: 'mail.messagingengine.com',
      port: 993,
      tls: true,
    });

    // Todo: SyncWorker should decide what operations to queue and what params
    // to pass them, and how often, based on SyncPolicy model (TBD).

    main.on('ready', () => {
      main.runOperation(new RefreshMailboxesOperation())
      .then(() =>
        this._db.Category.find({where: {role: 'inbox'}})
      ).then((inboxCategory) => {
        if (!inboxCategory) {
          throw new Error("Unable to find an inbox category.")
        }
        main.on('mail', () => {
          main.runOperation(new SyncMailboxOperation(inboxCategory));
        })
        main.on('update', () => {
          main.runOperation(new SyncMailboxOperation(inboxCategory));
        })
        main.on('queue-empty', () => {
          main.openBox(inboxCategory.name, true).then(() => {
            console.log("Idling on inbox category");
          });
        });

        setInterval(() => this.syncAllMailboxes(), 120 * 1000);
        this.syncAllMailboxes();
      });
    });

    this._db = db;
    this._main = main;
  }

  syncAllMailboxes() {
    const {Category} = this._db;
    Category.findAll().then((categories) => {
      const priority = ['inbox', 'drafts', 'sent'];
      const sorted = categories.sort((a, b) => {
        return priority.indexOf(b.role) - priority.indexOf(a.role);
      })
      for (const cat of sorted) {
        this._main.runOperation(new SyncMailboxOperation(cat));
      }
    });
  }
}

module.exports = SyncWorker;
