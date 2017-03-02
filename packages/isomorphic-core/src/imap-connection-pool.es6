const IMAPConnection = require('./imap-connection');
const IMAPErrors = require('./imap-errors');
const {ExponentialBackoffScheduler} = require('./backoff-schedulers');

const MAX_IMAP_CONNECTIONS_PER_ACCOUNT = 3;
const INITIAL_SOCKET_TIMEOUT_MS = 30 * 1000;  // 30 sec
const MAX_SOCKET_TIMEOUT_MS = 10 * 60 * 1000  // 10 min

class AccountConnectionPool {
  constructor(account, maxConnections) {
    this._account = account;
    this._availableConns = new Array(maxConnections).fill(null);
    this._queue = [];
    this._backoffScheduler = new ExponentialBackoffScheduler({
      baseDelay: INITIAL_SOCKET_TIMEOUT_MS,
      maxDelay: MAX_SOCKET_TIMEOUT_MS,
    });
  }

  async _genConnection(socketTimeout, logger) {
    const settings = this._account.connectionSettings;
    const credentials = this._account.decryptedCredentials();

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
      account: this._account,
    });

    return conn.connect();
  }

  async withConnections({desiredCount, logger, onConnected, onTimeout}) {
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

    this._backoffScheduler.reset();
    while (true) {
      const socketTimeout = this._backoffScheduler.nextDelay();
      let conns = [];
      let keepOpen = false;

      const done = () => {
        conns.filter(Boolean).forEach((conn) => conn.removeAllListeners());
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
        conns = await Promise.all(conns.map((c) => (c || this._genConnection(socketTimeout, logger))));

        // TODO: Indicate which connections had errors so that we can selectively
        // refresh them.
        keepOpen = await onConnected(conns, done);
        break;
      } catch (err) {
        keepOpen = false;
        conns.filter(Boolean).forEach(conn => conn.end());
        conns.fill(null);

        if (err instanceof IMAPErrors.IMAPConnectionTimeoutError) {
          if (onTimeout) onTimeout(socketTimeout);
          // Put an empty callback at the beginning of the queue so that we
          // don't wake another waiting Promise in the finally clause.
          this._queue.unshift(() => {});
          continue;
        }

        throw err;
      } finally {
        if (!keepOpen) {
          done();
        }
      }
    }
  }
}

class IMAPConnectionPool {
  constructor(maxConnectionsPerAccount) {
    this._maxConnectionsPerAccount = maxConnectionsPerAccount;
    this._poolMap = {};
  }

  async withConnectionsForAccount(account, {desiredCount, logger, onConnected, onTimeout}) {
    if (!this._poolMap[account.id]) {
      this._poolMap[account.id] = new AccountConnectionPool(account, this._maxConnectionsPerAccount);
    }

    const pool = this._poolMap[account.id];
    await pool.withConnections({desiredCount, logger, onConnected, onTimeout});
  }
}

module.exports = new IMAPConnectionPool(MAX_IMAP_CONNECTIONS_PER_ACCOUNT);
