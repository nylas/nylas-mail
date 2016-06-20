const Imap = require('imap');
const EventEmitter = require('events');

const RefreshMailboxesOperation = require('./imap/refresh-mailboxes-operation')
const DiscoverMessagesOperation = require('./imap/discover-messages-operation')
const ScanUIDsOperation = require('./imap/scan-uids-operation')

const Capabilities = {
  Gmail: 'X-GM-EXT-1',
  Quota: 'QUOTA',
  UIDPlus: 'UIDPLUS',
  Condstore: 'CONDSTORE',
  Search: 'ESEARCH',
  Sort: 'SORT',
}

class IMAPConnectionStateMachine extends EventEmitter {
  constructor(db, settings) {
    super();

    this._db = db;
    this._queue = [];
    this._current = null;
    this._capabilities = [];
    this._imap = Promise.promisifyAll(new Imap(settings));

    this._imap.once('ready', () => {
      for (const key of Object.keys(Capabilities)) {
        const val = Capabilities[key];
        if (this._imap.serverSupports(val)) {
          this._capabilities.push(val);
        }
      }
      this.emit('ready');
    });

    this._imap.once('error', (err) => {
      console.log(err);
    });

    this._imap.once('end', () => {
      console.log('Connection ended');
    });

    this._imap.on('alert', (msg) => {
      console.log(`IMAP SERVER SAYS: ${msg}`)
    })

    // Emitted when new mail arrives in the currently open mailbox.
    // Fix https://github.com/mscdex/node-imap/issues/445
    let lastMailEventBox = null;
    this._imap.on('mail', () => {
      if (lastMailEventBox === this._imap._box.name) {
        this.emit('mail');
      }
      lastMailEventBox = this._imap._box.name
    });

    // Emitted if the UID validity value for the currently open mailbox
    // changes during the current session.
    this._imap.on('uidvalidity', () => this.emit('uidvalidity'))

    // Emitted when message metadata (e.g. flags) changes externally.
    this._imap.on('update', () => this.emit('update'))

    this._imap.connect();
  }

  getIMAP() {
    return this._imap;
  }

  runOperation(operation) {
    return new Promise((resolve, reject) => {
      this._queue.push({operation, resolve, reject});
      if (this._imap.state === 'authenticated' && !this._current) {
        this.processNextOperation();
      }
    });
  }

  processNextOperation() {
    if (this._current) { return; }

    this._current = this._queue.shift();

    if (!this._current) {
      this.emit('queue-empty');
      return;
    }

    const {operation, resolve, reject} = this._current;

    console.log(`Starting task ${operation.description()}`)
    const result = operation.run(this._db, this._imap);
    if (result instanceof Promise === false) {
      throw new Error(`Expected ${operation.constructor.name} to return promise.`);
    }
    result.catch((err) => {
      this._current = null;
      console.error(err);
      reject();
    })
    .then(() => {
      this._current = null;
      console.log(`Finished task ${operation.description()}`)
      resolve();
    })
    .finally(() => {
      this.processNextOperation();
    });
  }
}

class SyncWorker {
  constructor(account, db) {
    const main = new IMAPConnectionStateMachine(db, {
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
          main.runOperation(new DiscoverMessagesOperation(inboxCategory));
        })
        main.on('update', () => {
          main.runOperation(new ScanUIDsOperation(inboxCategory));
        })
        main.on('queue-empty', () => {
          main.getIMAP().openBoxAsync(inboxCategory.name, true).then(() => {
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
        this._main.runOperation(new DiscoverMessagesOperation(cat));
        this._main.runOperation(new ScanUIDsOperation(cat));
      }
    });
  }
}

module.exports = SyncWorker;
