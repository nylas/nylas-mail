const SyncWorker = require('./sync-worker');
const {PromiseUtils} = require(`isomorphic-core`);
const LocalDatabaseConnector = require('../shared/local-database-connector')
const LocalPubsubConnector = require('../shared/local-pubsub-connector')

const IDENTITY = `${global.instanceId}-${process.pid}`;


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

    LocalDatabaseConnector.forShared().then(({Account}) =>
      Account.findAll().then((accounts) => {
        for (const account of accounts) {
          this.addWorkerForAccount(account);
        }
      }));
  }

  addWorkerForAccount(account) {
    return LocalDatabaseConnector.forAccount(account.id).then((db) => {
      if (this._workers[account.id]) {
        return Promise.reject(new Error("Local worker already exists"));
      }

      this._workers[account.id] = new SyncWorker(account, db, () => {
        this.removeWorkerForAccountId(account.id)
      });
      return Promise.resolve();
    })
    .then(() => {
      this._logger.info({account_id: account.id}, `ProcessManager: Claiming Account Succeeded`)
    })
    .catch((err) => {
      this._logger.error({account_id: account.id, reason: err.message}, `ProcessManager: Claiming Account Failed`)
    });
  }

  removeWorkerForAccountId(accountId) {
    this._workers[accountId] = null;
  }

}

module.exports = new SyncProcessManager();
