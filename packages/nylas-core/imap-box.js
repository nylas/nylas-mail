const _ = require('underscore');

const {
  IMAPConnectionNotReadyError,
} = require('./imap-errors');

class IMAPBox {
  constructor(imapConn, box) {
    this._conn = imapConn
    this._box = box

    return new Proxy(this, {
      get(target, name) {
        const prop = Reflect.get(target, name)
        if (!prop) {
          return Reflect.get(target._box, name)
        }
        if (_.isFunction(prop) && target._conn._imap._box.name !== target._box.name) {
          return () => Promise.reject(
            new Error(`IMAPBox::${name} - Can't operate on a mailbox that is no longer open on the current IMAPConnection.`)
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
  fetchEach(range, options, forEachMessageCallback) {
    if (!options) {
      throw new Error("IMAPBox.fetch now requires an options object.")
    }
    if (range.length === 0) {
      return Promise.resolve()
    }

    return this._conn.createConnectionPromise((resolve, reject) => {
      const f = this._conn._imap.fetch(range, options);
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
          forEachMessageCallback({attributes, headers, parts});
        });
      })
      f.once('error', reject);
      f.once('end', resolve);
    });
  }

  /**
   * @return {Promise} that resolves to requested message
   */
  fetchMessage(uid) {
    if (!uid) {
      throw new Error("IMAPConnection.fetchMessage requires a message uid.")
    }
    return this.fetchEach([uid], {
      bodies: ['HEADER', 'TEXT'],
    })
  }

  fetchMessageStream(uid, options) {
    if (!uid) {
      throw new Error("IMAPConnection.fetchStream requires a message uid.")
    }
    if (!options) {
      throw new Error("IMAPConnection.fetchStream requires an options object.")
    }
    return this._conn.createConnectionPromise((resolve, reject) => {
      const f = this._conn._imap.fetch(uid, options);
      f.on('message', (imapMessage) => {
        imapMessage.on('body', (stream) => {
          resolve(stream)
        })
      })
      f.once('error', reject)
    })
  }

  /**
   * @param {array|string} range - can be a single message identifier,
   * a message identifier range (e.g. '2504:2507' or '*' or '2504:*'),
   * an array of message identifiers, or an array of message identifier ranges.
   * @return {Promise} that resolves to a map of uid -> attributes for every
   * message in the range
   */
  fetchUIDAttributes(range) {
    return this._conn.createConnectionPromise((resolve, reject) => {
      const attributesByUID = {};
      const f = this._conn._imap.fetch(range, {});
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
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::addFlags`)
    }
    return this._conn._imap.addFlagsAsync(range, flags)
  }

  delFlags(range, flags) {
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::delFlags`)
    }
    return this._conn._imap.delFlagsAsync(range, flags)
  }

  moveFromBox(range, folderName) {
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::moveFromBox`)
    }
    return this._conn._imap.moveAsync(range, folderName)
  }

  closeBox({expunge = true} = {}) {
    if (!this._conn._imap) {
      throw new IMAPConnectionNotReadyError(`IMAPBox::closeBox`)
    }
    return this._conn._imap.closeBoxAsync(expunge)
  }
}

module.exports = IMAPBox;
