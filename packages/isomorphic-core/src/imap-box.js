const _ = require('underscore');

const {
  RetryableError,
  IMAPConnectionNotReadyError,
} = require('./imap-errors');

/*
IMAPBox uses Proxy to wrap the "box" exposed by node-imap. It provides higher-level
primitives, but you can still call through to properties / methods of the node-imap
box, ala `imapbox.uidvalidity`
*/
class IMAPBox {
  constructor(imapConn, box) {
    this._conn = imapConn
    this._box = box

    return new Proxy(this, {
      get(obj, prop) {
        const val = (prop in obj) ? obj[prop] : obj._box[prop];

        if (_.isFunction(val)) {
          const myBox = obj._box.name;
          const openBox = obj._conn.getOpenBoxName()
          if (myBox !== openBox) {
            return () => {
              throw new RetryableError(`IMAPBox::${prop} - Mailbox is no longer selected on the IMAPConnection (${myBox} != ${openBox}).`);
            }
          }
        }

        return val;
      },
    })
  }

  _withPreparedConnection(cb) {
    return this._conn._withPreparedConnection(cb)
  }

  /**
   * @param {array|string} range - can be a single message identifier,
   * a message identifier range (e.g. '2504:2507' or '*' or '2504:*'),
   * an array of message identifiers, or an array of message identifier ranges.
   * @param {Object} options
   * @param {function} forEachMessageCallback - function to be called with each
   * message as it comes in
   * @return {Promise} that will feed each message as it becomes ready
   */
  async fetchEach(range, options, forEachMessageCallback) {
    if (!options) {
      throw new Error("IMAPBox.fetch now requires an options object.")
    }
    if (range.length === 0) {
      return Promise.resolve()
    }

    return this._withPreparedConnection((imap) => {
      return new Promise((resolve, reject) => {
        const f = imap.fetch(range, options);
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
              const full = Buffer.concat(chunks);
              if (info.which === 'HEADER') {
                headers = full;
              } else {
                parts[info.which] = full;
              }
            });
          });
          imapMessage.once('end', () => {
            // attributes is an object containing ascii strings, but parts and
            // headers are undecoded binary Buffers (since the data for mime
            // parts cannot be decoded to strings without looking up charset data
            // in metadata, and this function's job is only to fetch the raw data)
            forEachMessageCallback({attributes, headers, parts});
          });
        })
        f.once('error', reject);
        f.once('end', resolve);
      })
    });
  }

  /**
   * @return {Promise} that resolves to requested message
   */
  async fetchMessage(uid) {
    if (!uid) {
      throw new Error("IMAPConnection.fetchMessage requires a message uid.")
    }
    let message;
    await this.fetchEach([uid], {bodies: ['HEADER', 'TEXT']}, (msg) => { message = msg; })
    return message
  }

  async fetchMessageStream(uid, {fetchOptions, onFetchComplete} = {}) {
    if (!uid) {
      throw new Error("IMAPConnection.fetchStream requires a message uid.")
    }
    if (!fetchOptions) {
      throw new Error("IMAPConnection.fetchStream requires an options object.")
    }
    return this.__withPreparedConnection((imap) => {
      return new Promise((resolve, reject) => {
        const f = imap.fetch(uid, fetchOptions);
        f.on('message', (imapMessage) => {
          imapMessage.on('body', (stream) => {
            resolve(stream)
          })
        })
        f.once('error', reject)
        f.once('end', onFetchComplete || (() => {}));
      })
    })
  }

  /**
   * @param {array|string} range - can be a single message identifier,
   * a message identifier range (e.g. '2504:2507' or '*' or '2504:*'),
   * an array of message identifiers, or an array of message identifier ranges.
   * @return {Promise} that resolves to a map of uid -> attributes for every
   * message in the range
   */
  async fetchUIDAttributes(range, fetchOptions = {}) {
    return this._withPreparedConnection((imap) => {
      return new Promise((resolve, reject) => {
        const attributesByUID = {};
        const f = imap.fetch(range, fetchOptions);
        f.on('message', (msg) => {
          msg.on('attributes', (attrs) => {
            attributesByUID[attrs.uid] = attrs;
          })
        });
        f.once('error', reject);
        f.once('end', () => resolve(attributesByUID));
      })
    });
  }

  addFlags(range, flags) {
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::addFlags`)
    }

    return this._withPreparedConnection((imap) => imap.addFlagsAsync(range, flags))
  }

  delFlags(range, flags) {
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::delFlags`)
    }
    return this._withPreparedConnection((imap) => imap.delFlagsAsync(range, flags))
  }

  moveFromBox(range, folderName) {
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::moveFromBox`)
    }
    return this._withPreparedConnection((imap) => imap.moveAsync(range, folderName))
  }

  setLabels(range, labels) {
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::moveFromBox`)
    }
    return this._withPreparedConnection((imap) => imap.setLabelsAsync(range, labels))
  }

  removeLabels(range, labels) {
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::moveFromBox`)
    }
    return this._withPreparedConnection((imap) => imap.delLabelsAsync(range, labels))
  }

  append(rawMime, options) {
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::append`)
    }
    return this._withPreparedConnection((imap) => imap.appendAsync(rawMime, options))
  }

  search(criteria) {
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::search`)
    }
    return this._withPreparedConnection((imap) => imap.searchAsync(criteria))
  }

  closeBox({expunge = true} = {}) {
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::closeBox`)
    }
    return this._withPreparedConnection((imap) => imap.closeBoxAsync(expunge))
  }
}

module.exports = IMAPBox;
