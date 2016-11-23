const SyncWorker = require('./sync-worker');
const {PromiseUtils} = require(`isomorphic-core`);
const LocalDatabaseConnector = require('../shared/local-database-connector')
const LocalPubsubConnector = require('../shared/local-pubsub-connector')
const SchedulerUtils = require('../shared/scheduler-utils')

const IDENTITY = `${global.instanceId}-${process.pid}`;

const {
  ACCOUNTS_FOR,
  ACCOUNTS_UNCLAIMED,
  ACCOUNTS_CLAIMED_PREFIX,
  HEARTBEAT_FOR,
  HEARTBEAT_EXPIRES,
  forEachAccountList,
} = SchedulerUtils;

/*
Accounts ALWAYS exist in either `accounts:unclaimed` or an `accounts:{id}` list.
They are atomically moved between these sets as they are claimed and returned.

Periodically, each worker in the pool looks at all the `accounts:{id}` lists.
For each list it finds, it checks for the existence of `heartbeat:{id}`, a key
that expires quickly if the sync process doesn't refresh it.

If it does not find the key, it moves all of the accounts in the list back to
the unclaimed key.

Sync processes only claim an account for a fixed period of time. This means that
an engineer can add new sync machines to the pool and the load across instances
will balance on it's own. It also means one bad instance will not permanently
disrupt sync for any accounts. (Eg: instance has faulty network connection.)

Sync processes periodically claim accounts when they can find them, regardless
of how busy they are. A separate API (`/routes/monitoring`) allows CloudWatch
to decide whether to spin up instances or take them offline based on CPU/RAM
utilization across the pool.
*/

class SyncProcessManager {
  constructor() {
    this._workers = {};
    this._listenForSyncsClient = null;
    this._exiting = false;
    this._logger = global.Logger.child({identity: IDENTITY})
  }

  start() {
    this._logger.info(`ProcessManager: Starting with ID`)

    this.unassignAccountsAssignedTo(IDENTITY).then(() => {
      this.unassignAccountsMissingHeartbeats();
      this.update();
    });

    setInterval(() => this.updateHeartbeat(), HEARTBEAT_EXPIRES / 5.0 * 1000);
    this.updateHeartbeat();

    process.on('SIGINT', () => this.onSigInt());
    process.on('SIGTERM', () => this.onSigInt());
  }

  updateHeartbeat() {
    const key = HEARTBEAT_FOR(IDENTITY);
    const client = LocalPubsubConnector.broadcastClient();
    client.setAsync(key, Date.now())
    .then(() => client.expireAsync(key, HEARTBEAT_EXPIRES))
    .then(() => {
      const accountsSyncing = Object.keys(this._workers).length
      this._logger.info({
        accounts_syncing_count: accountsSyncing,
      }, "ProcessManager: 💘")
    })
  }

  onSigInt() {
    this._logger.info(`ProcessManager: Exiting...`)
    this._exiting = true;

    this.unassignAccountsAssignedTo(IDENTITY).then(() =>
      LocalPubsubConnector.broadcastClient().delAsync(ACCOUNTS_FOR(IDENTITY)).then(() =>
        LocalPubsubConnector.broadcastClient().delAsync(HEARTBEAT_FOR(IDENTITY))
      )
    ).finally(() => {
      process.exit(1);
    });
  }

  ensureAccountIDsInRedis(accountIds) {
    const client = LocalPubsubConnector.broadcastClient();

    let unseenIds = [].concat(accountIds);

    this._logger.info("ProcessManager: Starting scan for accountIds in database that are not present in Redis.")

    return forEachAccountList((foundProcessIdentity, foundIds) => {
      unseenIds = unseenIds.filter((a) => !foundIds.includes(`${a}`))
    })
    .finally(() => {
      if (unseenIds.length === 0) {
        return;
      }
      this._logger.info({
        unseen_ids: unseenIds.join(', '),
        channel: ACCOUNTS_UNCLAIMED,
      }, `ProcessManager: Adding unseen account IDs to ACCOUNTS_UNCLAIMED channel.`)
      unseenIds.map((id) => client.lpushAsync(ACCOUNTS_UNCLAIMED, id));
    });
  }

  unassignAccountsMissingHeartbeats() {
    const client = LocalPubsubConnector.broadcastClient();

    this._logger.info("ProcessManager: Starting unassignment for processes missing heartbeats.")

    PromiseUtils.each(client.keysAsync(`${ACCOUNTS_CLAIMED_PREFIX}*`), (key) => {
      const id = key.replace(ACCOUNTS_CLAIMED_PREFIX, '');
      return client.existsAsync(HEARTBEAT_FOR(id)).then((exists) =>
        (exists ? Promise.resolve() : this.unassignAccountsAssignedTo(id))
      )
    })
    .finally(() => {
      const delay = HEARTBEAT_EXPIRES * 1000;
      setTimeout(() => this.unassignAccountsMissingHeartbeats(), delay);
    });
  }

  unassignAccountsAssignedTo(identity) {
    const src = ACCOUNTS_FOR(identity);
    const dst = ACCOUNTS_UNCLAIMED;

    const unassignOne = (count) =>
      LocalPubsubConnector.broadcastClient().rpoplpushAsync(src, dst).then((val) =>
        (val ? unassignOne(count + 1) : Promise.resolve(count))
      )

    return unassignOne(0).then((returned) => {
      this._logger.info({
        returned,
        assigned_to: identity,
      }, `ProcessManager: Returned accounts`)
    });
  }

  update() {
    this._logger.info(`ProcessManager: Searching for an unclaimed account to sync.`)

    this.acceptUnclaimedAccount().finally(() => {
      if (this._exiting) {
        return;
      }
      this.update();
    });
  }

  acceptUnclaimedAccount() {
    if (!this._waitForAccountClient) {
      this._waitForAccountClient = LocalPubsubConnector.buildClient();
    }

    const src = ACCOUNTS_UNCLAIMED;
    const dst = ACCOUNTS_FOR(IDENTITY);

    return this._waitForAccountClient.brpoplpushAsync(src, dst, 10000).then((accountId) => {
      if (!accountId) {
        return Promise.resolve();
      }
      this.addWorkerForAccountId(accountId);

      // If we've added an account, wait a second before asking for another one.
      // Spacing them out is probably healthy.
      return PromiseUtils.sleep(2000);
    });
  }

  addWorkerForAccountId(accountId) {
    LocalDatabaseConnector.forShared().then(({Account}) =>
      Account.find({where: {id: accountId}}).then((account) => {
        if (!account) {
          return Promise.reject(new Error("Could not find account"));
        }
        return LocalDatabaseConnector.forAccount(accountId).then((db) => {
          if (this._exiting || this._workers[accountId]) {
            return Promise.reject(new Error("Exiting or local worker already exists"));
          }
          this._workers[account.id] = new SyncWorker(account, db, () => {
            this.removeWorkerForAccountId(accountId)
          });
          return Promise.resolve();
        });
      })
    )
    .then(() => {
      this._logger.info({account_id: accountId}, `ProcessManager: Claiming Account Succeeded`)
    })
    .catch((err) => {
      this._logger.error({account_id: accountId, reason: err.message}, `ProcessManager: Claiming Account Failed`)
    });
  }

  removeWorkerForAccountId(accountId) {
    const src = ACCOUNTS_FOR(IDENTITY);
    const dst = ACCOUNTS_UNCLAIMED;

    return LocalPubsubConnector.broadcastClient().lremAsync(src, 1, accountId).then((didRemove) => {
      this._workers[accountId] = null;
      if (didRemove) {
        return LocalPubsubConnector.broadcastClient().rpushAsync(dst, accountId)
      }
      return Promise.reject(new Error("Did not own account."));
    })
    .then(() => {
      this._logger.info({account_id: accountId}, `ProcessManager: Relinquishing Account Succeeded`)
    })
    .catch((err) => {
      this._logger.error({account_id: accountId, reason: err.message}, `ProcessManager: Relinquishing Account Failed`)
    });
  }
}

module.exports = SyncProcessManager;
