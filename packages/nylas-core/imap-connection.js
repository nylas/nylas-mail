const Imap = require('imap');
const EventEmitter = require('events');
const xoauth2 = require("xoauth2");
const _ = require('underscore');

const Capabilities = {
  Gmail: 'X-GM-EXT-1',
  Quota: 'QUOTA',
  UIDPlus: 'UIDPLUS',
  Condstore: 'CONDSTORE',
  Search: 'ESEARCH',
  Sort: 'SORT',
}

class IMAPConnection extends EventEmitter {

  constructor(db, settings) {
    super();

    this._db = db;
    this._queue = [];
    this._current = null;
    this._settings = settings;
  }

  connect() {
    if (!this._connectPromise) {
      this._connectPromise = this._resolveIMAPSettings().then((settings) =>
        this._buildUnderlyingConnection(settings)
      )
    }
    return this._connectPromise;
  }

  _resolveIMAPSettings() {
    const result = {
      host: this._settings.imap_host,
      port: this._settings.imap_port,
      user: this._settings.imap_username,
      password: this._settings.imap_password,
      tls: this._settings.ssl_required,
    }

    if (this._settings.refresh_token) {
      const xoauthFields = ['client_id', 'client_secret', 'imap_username', 'refresh_token'];
      if (Object.keys(_.pick(this._settings, xoauthFields)).length !== 4) {
        throw new Error(`IMAPConnection: Expected ${xoauthFields.join(',')} when given refresh_token`)
      }
      return new Promise((resolve, reject) => {
        xoauth2.createXOAuth2Generator({
          clientId: this._settings.client_id,
          clientSecret: this._settings.client_secret,
          user: this._settings.imap_username,
          refreshToken: this._settings.refresh_token,
        }).getToken((err, token) => {
          if (err) { return reject(err) }
          delete result.password;
          result.xoauth2 = token;
          return resolve(result);
        });
      });
    }

    return Promise.resolve(result);
  }

  _buildUnderlyingConnection(settings) {
    return new Promise((resolve, reject) => {
      this._imap = Promise.promisifyAll(new Imap(settings));

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
      this._imap.once('ready', resolve);
      this._imap.once('error', reject);
      this._imap.connect();
    });
  }

  end() {
    this._queue = [];
    this._imap.end();
  }

  serverSupports(cap) {
    if (!this._imap) {
      throw new Error("IMAPConnection.serverSupports: You need to call connect() first.")
    }
    this._imap.serverSupports(cap);
  }

  openBox(box) {
    if (!this._imap) {
      throw new Error("IMAPConnection.openBox: You need to call connect() first.")
    }
    return this._imap.openBoxAsync(box, true);
  }

  getBoxes() {
    if (!this._imap) {
      throw new Error("IMAPConnection.getBoxes: You need to call connect() first.")
    }
    return this._imap.getBoxesAsync();
  }

  fetch(range, messageCallback) {
    if (!this._imap) {
      throw new Error("IMAPConnection.fetch: You need to call connect() first.")
    }
    return new Promise((resolve, reject) => {
      const f = this._imap.fetch(range, {
        bodies: ['HEADER', 'TEXT'],
      });
      f.on('message', (msg) =>
        this._receiveMessage(msg, messageCallback)
      )
      f.once('error', reject);
      f.once('end', resolve);
    });
  }

  fetchMessages(uids, messageCallback) {
    if (!this._imap) {
      throw new Error("IMAPConnection.fetchMessages: You need to call connect() first.")
    }
    if (uids.length === 0) {
      return Promise.resolve();
    }
    return this.fetch(uids, messageCallback);
  }

  fetchUIDAttributes(range) {
    if (!this._imap) {
      throw new Error("IMAPConnection.fetchUIDAttributes: You need to call connect() first.")
    }
    return new Promise((resolve, reject) => {
      const latestUIDAttributes = {};
      const f = this._imap.fetch(range, {});
      f.on('message', (msg) => {
        msg.on('attributes', (attrs) => {
          latestUIDAttributes[attrs.uid] = attrs;
        })
      });
      f.once('error', reject);
      f.once('end', () => {
        resolve(latestUIDAttributes);
      });
    });
  }

  _receiveMessage(msg, callback) {
    let attributes = null;
    let body = null;
    let headers = null;

    msg.on('attributes', (attrs) => {
      attributes = attrs;
    });
    msg.on('body', (stream, info) => {
      const chunks = [];

      stream.on('data', (chunk) => {
        chunks.push(chunk);
      });
      stream.once('end', () => {
        const full = Buffer.concat(chunks).toString('utf8');
        if (info.which === 'HEADER') {
          headers = full;
        }
        if (info.which === 'TEXT') {
          body = full;
        }
      });
    });
    msg.once('end', () => {
      callback(attributes, headers, body);
    });
  }

  runOperation(operation) {
    if (!this._imap) {
      throw new Error("IMAPConnection.runOperation: You need to call connect() first.")
    }
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
    const result = operation.run(this._db, this);
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

IMAPConnection.Capabilities = Capabilities;

module.exports = IMAPConnection
