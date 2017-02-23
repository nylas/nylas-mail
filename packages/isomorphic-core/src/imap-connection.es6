import Imap from 'imap';
import _ from 'underscore';
import xoauth2 from 'xoauth2';
import EventEmitter from 'events';

import CommonProviderSettings from 'imap-provider-settings';

import PromiseUtils from './promise-utils';
import IMAPBox from './imap-box';

import {
  convertImapError,
  IMAPConnectionTimeoutError,
  IMAPConnectionNotReadyError,
  IMAPConnectionEndedError,
} from './imap-errors';

const MAJOR_IMAP_PROVIDER_HOSTS = Object.keys(CommonProviderSettings).reduce(
  (hostnameSet, key) => {
    hostnameSet.add(CommonProviderSettings[key].imap_host);
    return hostnameSet;
  }, new Set())

const Capabilities = {
  Gmail: 'X-GM-EXT-1',
  Quota: 'QUOTA',
  UIDPlus: 'UIDPLUS',
  Condstore: 'CONDSTORE',
  Search: 'ESEARCH',
  Sort: 'SORT',
}

const ONE_HOUR_SECS = 60 * 60;
const SOCKET_TIMEOUT_MS = 30 * 1000;
const AUTH_TIMEOUT_MS = 30 * 1000;

class IMAPConnection extends EventEmitter {

  static DefaultSocketTimeout = SOCKET_TIMEOUT_MS;

  static connect(...args) {
    return new IMAPConnection(...args).connect()
  }

  constructor({db, account, settings, logger} = {}) {
    super();

    if (!(settings instanceof Object)) {
      throw new Error("IMAPConnection: Must be instantiated with `settings`")
    }
    if (!logger) {
      throw new Error("IMAPConnection: Must be instantiated with `logger`")
    }

    this._logger = logger;
    this._db = db;
    this._account = account;
    this._queue = [];
    this._currentOperation = null;
    this._settings = settings;
    this._imap = null;
    this._connectPromise = null;
    this._isOpeningBox = false;
  }

  static generateXOAuth2Token(username, accessToken) {
    // See https://developers.google.com/gmail/xoauth2_protocol
    // for more details.
    const s = `user=${username}\x01auth=Bearer ${accessToken}\x01\x01`
    return new Buffer(s).toString('base64');
  }

  get account() {
    return this._account
  }

  get logger() {
    return this._logger
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
    const settings = {
      host: this._settings.imap_host,
      port: this._settings.imap_port,
      user: this._settings.imap_username,
      password: this._settings.imap_password,
      tls: this._settings.ssl_required,
      socketTimeout: this._settings.socketTimeout || SOCKET_TIMEOUT_MS,
      authTimeout: this._settings.authTimeout || AUTH_TIMEOUT_MS,
    }
    if (!MAJOR_IMAP_PROVIDER_HOSTS.has(settings.host)) {
      settings.tlsOptions = { rejectUnauthorized: false };
    }

    if (process.env.NYLAS_DEBUG) {
      settings.debug = console.log;
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
          delete settings.password;
          settings.xoauth2 = token;
          settings.expiry_date = Math.floor(Date.now() / 1000) + ONE_HOUR_SECS;
          return resolve(settings);
        });
      });
    }

    // This account uses XOAuth2, and we have a token given to us by the
    // backend, which has the client secret.
    if (this._settings.xoauth2) {
      delete settings.password;
      settings.xoauth2 = this._settings.xoauth2;
      settings.expiry_date = this._settings.expiry_date;
    }

    return Promise.resolve(settings);
  }

  _buildUnderlyingConnection(settings) {
    return new Promise((resolve, reject) => {
      this._imap = PromiseUtils.promisifyAll(new Imap(settings));

      const socketTimeout = setTimeout(() => {
        reject(new IMAPConnectionTimeoutError('Socket timed out'))
      }, SOCKET_TIMEOUT_MS)

      // Emitted when new mail arrives in the currently open mailbox.
      let lastMailEventBox = null;
      this._imap.on('mail', () => {
        // Fix https://github.com/mscdex/node-imap/issues/585
        if (this._isOpeningBox) { return }
        if (!this._imap) { return }
        if (lastMailEventBox === null || lastMailEventBox === this._imap._box.name) {
          // Fix https://github.com/mscdex/node-imap/issues/445
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
        clearTimeout(socketTimeout)
        resolve(this)
      });

      this._imap.once('error', (err) => {
        clearTimeout(socketTimeout)
        this.end();
        reject(convertImapError(err));
      });

      this._imap.once('end', () => {
        clearTimeout(socketTimeout)
        this._logger.debug('Underlying IMAP Connection ended');
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
  openBox(folderName, {readOnly = false, refetchBoxInfo = false} = {}) {
    if (!folderName) {
      throw new Error('IMAPConnection::openBox - You must provide a folder name')
    }
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::openBox`)
    }
    if (!refetchBoxInfo && folderName === this.getOpenBoxName()) {
      return Promise.resolve(new IMAPBox(this, this._imap._box));
    }
    this._isOpeningBox = true
    return this._createConnectionPromise((resolve, reject) => {
      return this._imap.openBoxAsync(folderName, readOnly)
      .then((box) => {
        this._isOpeningBox = false
        resolve(new IMAPBox(this, box))
      })
      .catch((...args) => reject(...args))
    })
  }

  getLatestBoxStatus(folderName) {
    if (!folderName) {
      throw new Error('IMAPConnection::getLatestBoxStatus - You must provide a folder name')
    }
    if (folderName === this.getOpenBoxName()) {
      // If the box is already open, we need to re-issue a SELECT in order to
      // get the latest stats from the box (e.g. latest uidnext, etc)
      return this.openBox(folderName, {refetchBoxInfo: true})
    }
    return this._createConnectionPromise((resolve, reject) => {
      return this._imap.statusAsync(folderName)
      .then((...args) => resolve(...args))
      .catch((...args) => reject(...args))
    })
  }

  getBoxes() {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::getBoxes`)
    }
    return this._createConnectionPromise((resolve, reject) => {
      return this._imap.getBoxesAsync()
      .then((...args) => resolve(...args))
      .catch((...args) => reject(...args))
    })
  }

  addBox(folderName) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::addBox`)
    }
    return this._createConnectionPromise((resolve, reject) => {
      return this._imap.addBoxAsync(folderName)
      .then((...args) => resolve(...args))
      .catch((...args) => reject(...args))
    })
  }

  renameBox(oldFolderName, newFolderName) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::renameBox`)
    }
    return this._createConnectionPromise((resolve, reject) => {
      return this._imap.renameBoxAsync(oldFolderName, newFolderName)
      .then((...args) => resolve(...args))
      .catch((...args) => reject(...args))
    })
  }

  delBox(folderName) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::delBox`)
    }
    return this._createConnectionPromise((resolve, reject) => {
      return this._imap.delBoxAsync(folderName)
      .then((...args) => resolve(...args))
      .catch((...args) => reject(...args))
    })
  }

  getOpenBoxName() {
    return (this._imap && this._imap._box) ? this._imap._box.name : null;
  }

  runOperation(operation, ctx) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::runOperation`)
    }
    return new Promise((resolve, reject) => {
      this._queue.push({operation, ctx, resolve, reject});
      if (this._imap.state === 'authenticated' && !this._currentOperation) {
        this._processNextOperation();
      }
    });
  }

  /*
  Equivalent to new Promise, but allows you to easily create promises
  which are also rejected when the IMAP connection closes, ends or times out.
  This is important because node-imap sometimes just hangs the current
  fetch / action forever after emitting an `end` event, or doesn't actually
  timeout the socket.
  */
  _createConnectionPromise(callback) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::_createConnectionPromise`)
    }

    let onEnded = null;
    let onErrored = null;

    return new Promise((resolve, reject) => {
      const socketTimeout = setTimeout(() => {
        reject(new IMAPConnectionTimeoutError('Socket timed out'))
      }, SOCKET_TIMEOUT_MS)

      onEnded = () => {
        clearTimeout(socketTimeout)
        reject(new IMAPConnectionEndedError());
      };
      onErrored = (error) => {
        clearTimeout(socketTimeout)
        this.end()
        reject(convertImapError(error));
      };

      this._imap.once('error', onErrored);
      this._imap.once('end', onEnded);

      const cbResolve = (...args) => {
        clearTimeout(socketTimeout)
        resolve(...args)
      }
      const cbReject = (error) => {
        clearTimeout(socketTimeout)
        reject(convertImapError(error))
      }
      return callback(cbResolve, cbReject)
    })
    .finally(() => {
      if (this._imap) {
        this._imap.removeListener('error', onErrored);
        this._imap.removeListener('end', onEnded);
      }
    });
  }

  _processNextOperation() {
    if (this._currentOperation) {
      return;
    }
    this._currentOperation = this._queue.shift();
    if (!this._currentOperation) {
      this.emit('queue-empty');
      return;
    }

    const {operation, ctx, resolve, reject} = this._currentOperation;
    const resultPromise = operation.run(this._db, this, ctx);
    if (resultPromise.constructor.name !== "Promise") {
      reject(new Error(`Expected ${operation.constructor.name} to return promise.`))
    }

    resultPromise.then((maybeResult) => {
      this._currentOperation = null;
      // this._logger.info({
      //   operation_type: operation.constructor.name,
      //   operation_description: operation.description(),
      // }, `Finished sync operation`)
      resolve(maybeResult);
      this._processNextOperation();
    })
    .catch((err) => {
      this._currentOperation = null;
      this._logger.error({
        error: err,
        operation_type: operation.constructor.name,
        operation_description: operation.description(),
      }, `IMAPConnection - operation errored`)
      reject(err);
    })
  }
}

IMAPConnection.Capabilities = Capabilities;
module.exports = IMAPConnection
