import Imap from 'imap';
import _ from 'underscore';
import xoauth2 from 'xoauth2';
import EventEmitter from 'events';
import CommonProviderSettings from 'imap-provider-settings';
import PromiseUtils from './promise-utils';
import IMAPBox from './imap-box';
import {RetryableError} from './errors'
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
const AUTH_TIMEOUT_MS = 30 * 1000;
const DEFAULT_SOCKET_TIMEOUT_MS = 30 * 1000;

export default class IMAPConnection extends EventEmitter {

  static DefaultSocketTimeout = DEFAULT_SOCKET_TIMEOUT_MS;

  static connect(...args) {
    return new IMAPConnection(...args).connect()
  }

  static asyncResolveIMAPSettings(baseSettings) {
    const settings = {
      host: baseSettings.imap_host,
      port: baseSettings.imap_port,
      user: baseSettings.imap_username,
      password: baseSettings.imap_password,
      tls: baseSettings.ssl_required,
      socketTimeout: baseSettings.socketTimeout || DEFAULT_SOCKET_TIMEOUT_MS,
      authTimeout: baseSettings.authTimeout || AUTH_TIMEOUT_MS,
    }
    if (!MAJOR_IMAP_PROVIDER_HOSTS.has(settings.host)) {
      settings.tlsOptions = { rejectUnauthorized: false };
    }

    if (process.env.NYLAS_DEBUG) {
      settings.debug = console.log;
    }

    // This account uses XOAuth2, and we have the client_id + refresh token
    if (baseSettings.refresh_token) {
      const xoauthFields = ['client_id', 'client_secret', 'imap_username', 'refresh_token'];
      if (Object.keys(_.pick(baseSettings, xoauthFields)).length !== 4) {
        return Promise.reject(new Error(`IMAPConnection: Expected ${xoauthFields.join(',')} when given refresh_token`))
      }
      return new Promise((resolve, reject) => {
        xoauth2.createXOAuth2Generator({
          clientId: baseSettings.client_id,
          clientSecret: baseSettings.client_secret,
          user: baseSettings.imap_username,
          refreshToken: baseSettings.refresh_token,
        })
        .getToken((err, token) => {
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
    if (baseSettings.xoauth2) {
      delete settings.password;
      settings.xoauth2 = baseSettings.xoauth2;
      settings.expiry_date = baseSettings.expiry_date;
    }

    return Promise.resolve(settings);
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
    this._baseSettings = settings;
    this._resolvedSettings = null;
    this._imap = null;
    this._connectPromise = null;
    this._isOpeningBox = false;
    this._lastOpenDuration = null;
  }

  async connect() {
    if (!this._connectPromise) {
      this._connectPromise = new Promise(async (resolve, reject) => {
        try {
          this._resolvedSettings = await IMAPConnection.asyncResolveIMAPSettings(this._baseSettings)
          await this._buildUnderlyingConnection()
          resolve(this)
        } catch (err) {
          reject(err)
        }
      })
    }
    return this._connectPromise;
  }

  end() {
    if (this._imap) {
      this._imap.end();
      this._imap = null;
    }
    this._queue = [];
    this._connectPromise = null;
  }

  async _buildUnderlyingConnection() {
    this._imap = PromiseUtils.promisifyAll(new Imap(this._resolvedSettings));
    return this._withPreparedConnection(() => {
      return new Promise((resolve) => {
        // `mail` event is emitted when new mail arrives in the currently open mailbox.
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

        this._imap.on('alert', (msg) => {
          this._logger.info({imap_server_msg: msg}, `IMAP server message`)
        });

        this._imap.once('ready', () => {
          resolve()
        });

        this._imap.once('error', () => {
          this.end();
        });

        this._imap.once('end', () => {
          this._logger.warn('Underlying IMAP connection has ended')
          this.end();
        });

        this._imap.connect();
      });
    })
  }

  /**
   * @return {Promise} that resolves/rejects when the Promise returned by the
   * passed-in callback resolves or rejects, and additionally will reject when
   * the IMAP connection closes, ends or times out.
   * This is important for 2 main reasons:
   * - node-imap can sometimes hang the current operation after the connection
   *   has emmitted an `end` event. For this reason, we need to manually reject
   *   and end() on `end` event.
   * - node-imap does not seem to respect the socketTimeout setting, so it won't
   *   actually time out an operation after the specified timeout has passed.
   *   For this reason, we have to manually reject when the timeout period has
   *   passed.
   * @param {function} callback - This callback will receive as a single arg
   * a node-imap connection instance, and should return a Promise.
   */
  async _withPreparedConnection(callback) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::_withPreparedConnection`)
    }

    if (this._isOpeningBox) {
      throw new RetryableError('IMAPConnection: Cannot operate on connection while opening a box.')
    }

    let onEnded = null;
    let onErrored = null;

    try {
      return await new Promise(async (resolve, reject) => {
        const socketTimeout = setTimeout(() => {
          reject(new IMAPConnectionTimeoutError('Socket timed out'))
        }, this._resolvedSettings.socketTimeout)

        const wrappedResolve = (result) => {
          clearTimeout(socketTimeout)
          resolve(result)
        }
        const wrappedReject = (error) => {
          clearTimeout(socketTimeout)
          const convertedError = convertImapError(error)
          reject(convertedError)
          this.end()
        }

        onEnded = () => {
          wrappedReject(new IMAPConnectionEndedError())
        };
        onErrored = (error) => {
          wrappedReject(error);
        };

        this._imap.on('error', onErrored);
        this._imap.on('end', onEnded);

        try {
          const result = await callback(this._imap)
          wrappedResolve(result)
        } catch (error) {
          wrappedReject(error)
        }
      })
    } finally {
      if (this._imap) {
        this._imap.removeListener('error', onErrored);
        this._imap.removeListener('end', onEnded);
      }
    }
  }

  getResolvedSettings() {
    return this._resolvedSettings
  }

  getOpenBoxName() {
    return (this._imap && this._imap._box) ? this._imap._box.name : null;
  }

  serverSupports(capability) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::serverSupports`)
    }
    return this._imap.serverSupports(capability);
  }

  getLastOpenDuration() {
    if (this._isOpeningBox) {
      throw new RetryableError('IMAPConnection: Cannot operate on connection while opening a box.')
    }
    return this._lastOpenDuration;
  }

  /**
   * @return {Promise} that resolves to instance of IMAPBox
   */
  async openBox(folderName, {readOnly = false, refetchBoxInfo = false} = {}) {
    if (!folderName) {
      throw new Error('IMAPConnection::openBox - You must provide a folder name')
    }
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::openBox`)
    }
    if (!refetchBoxInfo && folderName === this.getOpenBoxName()) {
      return Promise.resolve(new IMAPBox(this, this._imap._box));
    }
    return this._withPreparedConnection(async (imap) => {
      try {
        this._isOpeningBox = true
        this._lastOpenDuration = null;
        const before = Date.now();
        const box = await imap.openBoxAsync(folderName, readOnly)
        this._lastOpenDuration = Date.now() - before;
        this._isOpeningBox = false
        return new IMAPBox(this, box)
      } finally {
        this._isOpeningBox = false
      }
    })
  }

  async getLatestBoxStatus(folderName) {
    if (!folderName) {
      throw new Error('IMAPConnection::getLatestBoxStatus - You must provide a folder name')
    }
    if (folderName === this.getOpenBoxName()) {
      // If the box is already open, we need to re-issue a SELECT in order to
      // get the latest stats from the box (e.g. latest uidnext, etc)
      return this.openBox(folderName, {refetchBoxInfo: true})
    }
    return this._withPreparedConnection((imap) => imap.statusAsync(folderName))
  }

  async getBoxes() {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::getBoxes`)
    }
    return this._withPreparedConnection((imap) => imap.getBoxesAsync())
  }

  async addBox(folderName) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::addBox`)
    }
    return this._withPreparedConnection((imap) => imap.addBoxAsync(folderName))
  }

  async renameBox(oldFolderName, newFolderName) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::renameBox`)
    }
    return this._withPreparedConnection((imap) => imap.renameBoxAsync(oldFolderName, newFolderName))
  }

  async delBox(folderName) {
    if (!this._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPConnection::delBox`)
    }
    return this._withPreparedConnection((imap) => imap.delBoxAsync(folderName))
  }

  async runOperation(operation, ctx) {
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
