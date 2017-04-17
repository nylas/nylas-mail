const IMAPConnection = require('./imap-connection').default;
const {inDevMode} = require('./env-helpers')

const MAX_DEV_MODE_CONNECTIONS = 3
const MAX_GMAIL_CONNECTIONS = 7;
const MAX_O365_CONNECTIONS = 5;
const MAX_ICLOUD_CONNECTIONS = 5;
const MAX_IMAP_CONNECTIONS = 5;

class AccountConnectionPool {
  constructor(maxConnections) {
    this._availableConns = new Array(maxConnections).fill(null);
    this._queue = [];
  }

  async _genConnection(account, socketTimeout, logger) {
    const settings = account.connectionSettings;
    const credentials = account.decryptedCredentials();

    if (!settings || !settings.imap_host) {
      throw new Error("_genConnection: There are no IMAP connection settings for this account.");
    }
    if (!credentials) {
      throw new Error("_genConnection: There are no IMAP connection credentials for this account.");
    }

    const conn = new IMAPConnection({
      db: null,
      settings: Object.assign({}, settings, credentials, {socketTimeout}),
      logger,
      account,
    });

    return conn.connect();
  }

  async withConnections({account, desiredCount, logger, socketTimeout, onConnected}) {
    // If we wake up from the first await but don't have enough connections in
    // the pool then we need to prepend ourselves to the queue until there are
    // enough. This guarantees that the queue is fair.
    let prependToQueue = false;
    while (this._availableConns.length < desiredCount) {
      await new Promise((resolve) => {
        if (prependToQueue) {
          this._queue.unshift(resolve);
        } else {
          this._queue.push(resolve);
        }
      });
      prependToQueue = true;
    }

    let conns = [];
    let keepOpen = false;
    let calledOnDone = false;

    const onDone = () => {
      if (calledOnDone) { return }
      calledOnDone = true
      keepOpen = false;

      conns.filter(Boolean).forEach(conn => conn.end());
      conns.filter(Boolean).forEach(conn => conn.removeAllListeners());
      conns.fill(null);
      this._availableConns = conns.concat(this._availableConns);
      if (this._queue.length > 0) {
        const resolveWaitForConnection = this._queue.shift();
        resolveWaitForConnection();
      }
    };

    try {
      for (let i = 0; i < desiredCount; ++i) {
        conns.push(this._availableConns.shift());
      }
      conns = await Promise.all(
        conns.map(() => this._genConnection(account, socketTimeout, logger))
      );

      keepOpen = await onConnected(conns, onDone);
      if (!keepOpen) {
        onDone();
      }
    } catch (err) {
      onDone()
      throw err;
    }
  }
}

class IMAPConnectionPool {
  constructor() {
    this._poolMap = {};
  }

  _maxConnectionsForAccount(account) {
    if (inDevMode()) {
      return MAX_DEV_MODE_CONNECTIONS;
    }

    switch (account.provider) {
      case 'gmail': return MAX_GMAIL_CONNECTIONS;
      case 'office365': return MAX_O365_CONNECTIONS;
      case 'icloud': return MAX_ICLOUD_CONNECTIONS;
      case 'imap': return MAX_IMAP_CONNECTIONS;
      default: return MAX_DEV_MODE_CONNECTIONS;
    }
  }

  async withConnectionsForAccount(account, {desiredCount, logger, socketTimeout, onConnected}) {
    if (!this._poolMap[account.id]) {
      this._poolMap[account.id] = new AccountConnectionPool(this._maxConnectionsForAccount(account));
    }

    const pool = this._poolMap[account.id];
    await pool.withConnections({account, desiredCount, logger, socketTimeout, onConnected});
  }
}

module.exports = new IMAPConnectionPool();
