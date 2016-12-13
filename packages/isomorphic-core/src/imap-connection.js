const Imap = require('imap');
const _ = require('underscore');
const xoauth2 = require('xoauth2');
const EventEmitter = require('events');

const PromiseUtils = require('./promise-utils')
const IMAPBox = require('./imap-box');
const {
  convertImapError,
  IMAPConnectionNotReadyError,
  IMAPConnectionEndedError,
} = require('./imap-errors');

const Capabilities = {
  Gmail: 'X-GM-EXT-1',
  Quota: 'QUOTA',
  UIDPlus: 'UIDPLUS',
  Condstore: 'CONDSTORE',
  Search: 'ESEARCH',
  Sort: 'SORT',
}

class IMAPConnection extends EventEmitter {

  static connect(...args) {
    return new IMAPConnection(...args).connect()
  }

  constructor({db, settings, logger} = {}) {
    super();

    if (!(settings instanceof Object)) {
      throw new Error("IMAPConnection: Must be instantiated with `settings`")
    }
    if (!logger) {
      throw new Error("IMAPConnection: Must be instantiated with `logger`")
    }

    this._logger = logger;
    this._db = db;
    this._queue = [];
    this._currentOperation = null;
    this._settings = settings;
    this._imap = null;
    this._connectPromise = null;
  }

  connect() {
    if (!this._connectPromise) {
      this._connectPromise = this._resolveIMAPSettings().then((settings) => {
        this.resolvedSettings = settings
        return this._buildUnderlyingConnection(settings)
      });
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

    // This account uses XOAuth2, and we have the client_id + refresh token
    if (this._settings.refresh_token) {
      const xoauthFields = ['client_id', 'client_secret', 'imap_username', 'refresh_token'];
      if (Object.keys(_.pick(this._settings, xoauthFields)).length !== 4) {
        return Promise.reject(new Error(`IMAPConnection: Expected ${xoauthFields.join(',')} when given refresh_token`))
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

    // This account uses XOAuth2, and we have a token given to us by the
    // backend, which has the client secret.
    if (this._settings.xoauth2) {
      delete result.password;
      result.xoauth2 = this._settings.xoauth2;
    }

    return Promise.resolve(result);
  }

  _buildUnderlyingConnection(settings) {
    return new Promise((resolve, reject) => {
      this._imap = PromiseUtils.promisifyAll(new Imap(settings));

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

      this._imap.once('ready', () => {
        resolve(this)
      });

      this._imap.once('error', (err) => {
        this.end();
        reject(convertImapError(err));
      });

      this._imap.once('end', () => {
        this._logger.info('Underlying IMAP Connection ended');
        this._connectPromise = null;
        this._imap = null;
      });

      this._imap.on('alert', (msg) => {
        this._logger.info({imap_server_msg: msg}, `IMAP server message`)
      });

      this._imap.connect();
    });
  }

  end() {
    if (this._imap) {
      this._imap.end();
      this._imap = null;
    }
    this._queue = [];
    this._connectPromise = null;
  }

  serverSupports(capability) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::serverSupports`)
    }
    return this._imap.serverSupports(capability);
  }

  /**
   * @return {Promise} that resolves to instance of IMAPBox
   */
  openBox(folderName, {readOnly = false} = {}) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::openBox`)
    }
    return this._imap.openBoxAsync(folderName, readOnly).then((box) =>
      new IMAPBox(this, box)
    )
  }

  getBoxes() {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::getBoxes`)
    }
    return this._imap.getBoxesAsync()
  }

  addBox(folderName) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::addBox`)
    }
    return this._imap.addBoxAsync(folderName)
  }

  renameBox(oldFolderName, newFolderName) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::renameBox`)
    }
    return this._imap.renameBoxAsync(oldFolderName, newFolderName)
  }

  delBox(folderName) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::delBox`)
    }
    return this._imap.delBoxAsync(folderName)
  }

  getOpenBoxName() {
    return (this._imap && this._imap._box) ? this._imap._box.name : null;
  }

  runOperation(operation) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::runOperation`)
    }
    return new Promise((resolve, reject) => {
      this._queue.push({operation, resolve, reject});
      if (this._imap.state === 'authenticated' && !this._currentOperation) {
        this.processNextOperation();
      }
    });
  }

  /*
  Equivalent to new Promise, but allows you to easily create promises
  which are also rejected when the IMAP connection is closed or ends.
  This is important because node-imap sometimes just hangs the current
  fetch / action forever after emitting an `end` event.
  */
  createConnectionPromise(callback) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::createConnectionPromise`)
    }

    let onEnded = null;
    let onErrored = null;

    return new Promise((resolve, reject) => {
      let returned = false;
      onEnded = () => {
        returned = true;
        reject(new IMAPConnectionEndedError());
      };
      onErrored = (error) => {
        returned = true;
        reject(convertImapError(error));
      };

      this._imap.once('error', onErrored);
      this._imap.once('end', onEnded);

      const cresolve = (...args) => (!returned ? resolve(...args) : null)
      const creject = (...args) => (!returned ? reject(...args) : null)
      return callback(cresolve, creject)
    })
    .finally(() => {
      if (this._imap) {
        this._imap.removeListener('error', onErrored);
        this._imap.removeListener('end', onEnded);
      }
    });
  }

  processNextOperation() {
    if (this._currentOperation) {
      return;
    }
    this._currentOperation = this._queue.shift();
    if (!this._currentOperation) {
      this.emit('queue-empty');
      return;
    }

    const {operation, resolve, reject} = this._currentOperation;
    const resultPromise = operation.run(this._db, this);
    if (resultPromise.constructor.name !== "Promise") {
      reject(new Error(`Expected ${operation.constructor.name} to return promise.`))
    }

    resultPromise.then((maybeResult) => {
      this._currentOperation = null;
      this._logger.info({
        operation_type: operation.constructor.name,
        operation_description: operation.description(),
      }, `Finished sync operation`)
      resolve(maybeResult);
      this.processNextOperation();
    })
    .catch((err) => {
      this._currentOperation = null;
      this._logger.error({
        err,
        operation_type: operation.constructor.name,
        operation_description: operation.description(),
      }, `Sync operation errored`)
      reject(err);
    })
  }
}

IMAPConnection.Capabilities = Capabilities;
module.exports = IMAPConnection
