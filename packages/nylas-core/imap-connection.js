const Rx = require('rx')
const Imap = require('imap');
const _ = require('underscore');
const xoauth2 = require('xoauth2');
const EventEmitter = require('events');


class IMAPBox {

  constructor(imapConn, box) {
    this._imap = imapConn
    this._box = box
    return new Proxy(this, {
      get(target, name) {
        const prop = Reflect.get(target, name)
        if (!prop) {
          return Reflect.get(target._box, name)
        }
        if (_.isFunction(prop) && target._imap._box.name !== target._box.name) {
          return () => Promise.reject(
            new NylasError(`IMAPBox::${name} - Can't operate on a mailbox that is no longer open on the current IMAPConnection.`)
          )
        }
        return prop
      },
    })
  }

  /**
   * @param {array|string} range - can be a single message identifier,
   * a message identifier range (e.g. '2504:2507' or '*' or '2504:*'),
   * an array of message identifiers, or an array of message identifier ranges.
   * @return {Observable} that will feed each message as it becomes ready
   */
  fetch(range, options) {
    if (range.length === 0) {
      return Rx.Observable.empty()
    }
    if (!options) {
      throw new Error("IMAPBox.fetch now requires an options object.")
    }
    return Rx.Observable.create((observer) => {
      const f = this._imap.fetch(range, options);
      f.on('message', (imapMessage) => {
        const parts = {};
        let headers = null;
        let attributes = null;
        imapMessage.on('attributes', (attrs) => {
          attributes = attrs;
        });
        imapMessage.on('body', (stream, info) => {
          const chunks = [];

          stream.on('data', (chunk) => {
            chunks.push(chunk);
          });

          stream.once('end', () => {
            const full = Buffer.concat(chunks).toString('utf8');
            if (info.which === 'HEADER') {
              headers = full;
            } else {
              parts[info.which] = full;
            }
          });
        });
        imapMessage.once('end', () => {
          observer.onNext({attributes, headers, parts});
        });
      })
      f.once('error', (error) => observer.onError(error))
      f.once('end', () => observer.onCompleted())
    })
  }

  fetchStream({messageId, options}) {
    if (!messageId) {
      throw new Error("IMAPConnection.fetchStream requires a message identifier.")
    }
    if (!options) {
      throw new Error("IMAPConnection.fetchStream requires an options object.")
    }
    return new Promise((resolve, reject) => {
      const f = this._imap.fetch(messageId, options);
      f.on('message', (imapMessage) => {
        imapMessage.on('body', (stream) => {
          resolve(stream)
        })
      })
      f.once('error', (error) => reject)
    })
  }

  /**
   * @return {Promise} that resolves to requested message
   */
  fetchMessage(uid) {
    return this.fetch([uid], {
      bodies: ['HEADER', 'TEXT'],
    }).toPromise()
  }

  /**
   * @param {array|string} range - can be a single message identifier,
   * a message identifier range (e.g. '2504:2507' or '*' or '2504:*'),
   * an array of message identifiers, or an array of message identifier ranges.
   * @return {Promise} that resolves to a map of uid -> attributes for every
   * message in the range
   */
  fetchUIDAttributes(range) {
    return new Promise((resolve, reject) => {
      const attributesByUID = {};
      const f = this._imap.fetch(range, {});
      f.on('message', (msg) => {
        msg.on('attributes', (attrs) => {
          attributesByUID[attrs.uid] = attrs;
        })
      });
      f.once('error', reject);
      f.once('end', () => resolve(attributesByUID));
    });
  }

  addFlags(range, flags) {
    if (!this._imap) {
      throw new Error(`IMAPBox::addFlags - You need to call connect() first.`)
    }
    return this._imap.addFlagsAsync(range, flags)
  }

  delFlags(range, flags) {
    if (!this._imap) {
      throw new Error(`IMAPBox::delFlags - You need to call connect() first.`)
    }
    return this._imap.delFlagsAsync(range, flags)
  }

  moveFromBox(range, categoryName) {
    if (!this._imap) {
      throw new Error(`IMAPBox::moveFromBox - You need to call connect() first.`)
    }
    return this._imap.moveAsync(range, categoryName)
  }

  closeBox({expunge = true} = {}) {
    if (!this._imap) {
      throw new Error(`IMAPBox::closeBox - You need to call connect() first.`)
    }
    return this._imap.closeBoxAsync(expunge)
  }


}


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

  constructor(db, settings) {
    super();
    this._db = db;
    this._queue = [];
    this._currentOperation = null;
    this._settings = settings;
    this._imap = null
  }

  connect() {
    if (!this._connectPromise) {
      this._connectPromise = this._resolveIMAPSettings()
      .then((settings) => this._buildUnderlyingConnection(settings))
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
        return Promise.reject(new NylasError(`IMAPConnection: Expected ${xoauthFields.join(',')} when given refresh_token`))
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
      this._imap.once('ready', () => resolve(this));
      this._imap.once('error', reject);
      this._imap.connect();
    });
  }

  end() {
    this._queue = [];
    this._imap.end();
    this._imap = null;
  }

  serverSupports(capability) {
    if (!this._imap) {
      throw new Error(`IMAPConnection::serverSupports - You need to call connect() first.`)
    }
    this._imap.serverSupports(capability);
  }

  /**
   * @return {Promise} that resolves to instance of IMAPBox
   */
  openBox(categoryName, {readOnly = false} = {}) {
    if (!this._imap) {
      throw new Error(`IMAPConnection::openBox - You need to call connect() first.`)
    }
    return this._imap.openBoxAsync(categoryName, readOnly).then((box) =>
      new IMAPBox(this._imap, box)
    )
  }

  getBoxes() {
    if (!this._imap) {
      throw new Error(`IMAPConnection::getBoxes - You need to call connect() first.`)
    }
    return this._imap.getBoxesAsync()
  }

  runOperation(operation) {
    if (!this._imap) {
      throw new Error(`IMAPConnection::runOperation - You need to call connect() first.`)
    }
    return new Promise((resolve, reject) => {
      this._queue.push({operation, resolve, reject});
      if (this._imap.state === 'authenticated' && !this._currentOperation) {
        this.processNextOperation();
      }
    });
  }

  processNextOperation() {
    if (this._currentOperation) { return }
    this._currentOperation = this._queue.shift();
    if (!this._currentOperation) {
      this.emit('queue-empty');
      return
    }

    const {operation, resolve, reject} = this._currentOperation;
    const result = operation.run(this._db, this);
    if (result instanceof Promise === false) {
      reject(new NylasError(`Expected ${operation.constructor.name} to return promise.`))
    }
    result
    .then(() => {
      this._currentOperation = null;
      console.log(`Finished task: ${operation.description()}`)
      resolve();
      this.processNextOperation();
    })
    .catch((err) => {
      this._currentOperation = null;
      console.log(`Task errored: ${operation.description()}`)
      console.error(err)
      reject(err);
    })
  }
}
IMAPConnection.Capabilities = Capabilities;

module.exports = IMAPConnection
