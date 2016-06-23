const os = require('os');
const SyncWorker = require('./sync-worker');
const {DatabaseConnector, PubsubConnector} = require(`nylas-core`)

const CPU_COUNT = os.cpus().length;
const IDENTITY = `${os.hostname()}-${process.pid}`;

const ACCOUNTS_UNCLAIMED = 'accounts:unclaimed';
const ACCOUNTS_CLAIMED_PREFIX = 'accounts:id-';
const ACCOUNTS_FOR = (id) => `${ACCOUNTS_CLAIMED_PREFIX}${id}`;
const HEARTBEAT_FOR = (id) => `heartbeat:${id}`;
const HEARTBEAT_EXPIRES = 30; // 2 min in prod?
const CLAIM_DURATION = 10 * 60 * 1000; // 2 hours on prod?

/*
Accounts ALWAYS exist in either `accounts:unclaimed` or an `accounts:{id}` list.
They are atomically moved between these sets as they are claimed and returned.

Periodically, each worker in the pool looks at all the `accounts:{id}` lists.
For each list it finds, it checks for the existence of `heartbeat:{id}`, a key
that expires quickly if the sync process doesn't refresh it.

If it does not find the key, it moves all of the accounts in the list back to
the unclaimed key.
*/

class SyncProcessManager {
  constructor() {
    this._workers = {};
    this._listenForSyncsClient = null;
    this._exiting = false;
  }

  start() {
    console.log(`ProcessManager: Starting with ID ${IDENTITY}`)

    this.unassignAccountsAssignedTo(IDENTITY).then(() => {
      this.unassignAccountsMissingHeartbeats();
      this.update();
    });

    setInterval(() => this.updateHeartbeat(), HEARTBEAT_EXPIRES / 5.0 * 1000);
    this.updateHeartbeat();

    process.on('SIGINT', () => this.onSigInt());
  }

  updateHeartbeat() {
    const key = HEARTBEAT_FOR(IDENTITY);
    const client = PubsubConnector.broadcastClient();
    client.setAsync(key, Date.now()).then(() =>
      client.expireAsync(key, HEARTBEAT_EXPIRES)
    ).then(() =>
      console.log("ProcessManager: Published heartbeat.")
    )
  }

  onSigInt() {
    console.log(`ProcessManager: Exiting...`)
    this._exiting = true;

    this.unassignAccountsAssignedTo(IDENTITY).then(() =>
      PubsubConnector.broadcastClient().delAsync(ACCOUNTS_FOR(IDENTITY)).then(() =>
        PubsubConnector.broadcastClient().delAsync(HEARTBEAT_FOR(IDENTITY))
      )
    ).finally(() => {
      process.exit(1);
    });
  }

  ensureAccountIDsInRedis(accountIds) {
    const client = PubsubConnector.broadcastClient();

    let unseenIds = [].concat(accountIds);

    return Promise.each(client.keysAsync(`accounts:*`), (key) =>
      client.lrangeAsync(key, 0, 20000).then((foundIds) => {
        unseenIds = unseenIds.filter((a) => !foundIds.includes(`${a}`))
      })
    ).finally(() => {
      if (unseenIds.length === 0) {
        return;
      }
      console.log(`ProcessManager: Adding account IDs ${unseenIds.join(',')} to ${ACCOUNTS_UNCLAIMED}.`)
      unseenIds.map((id) => client.lpushAsync(ACCOUNTS_UNCLAIMED, id));
    });
  }

  unassignAccountsMissingHeartbeats() {
    const client = PubsubConnector.broadcastClient();

    console.log("ProcessManager: Starting unassignment for processes missing heartbeats.")

    Promise.each(client.keysAsync(`${ACCOUNTS_CLAIMED_PREFIX}*`), (key) => {
      const id = key.replace(ACCOUNTS_CLAIMED_PREFIX, '');
      return client.existsAsync(HEARTBEAT_FOR(id)).then((exists) =>
        (exists ? Promise.resolve() : this.unassignAccountsAssignedTo(id))
      )
    }).finally(() => {
      const delay = HEARTBEAT_EXPIRES * 1000;
      setTimeout(() => this.unassignAccountsMissingHeartbeats(), delay);
    });
  }

  unassignAccountsAssignedTo(identity) {
    const src = ACCOUNTS_FOR(identity);
    const dst = ACCOUNTS_UNCLAIMED;

    const unassignOne = (count) =>
      PubsubConnector.broadcastClient().rpoplpushAsync(src, dst).then((val) =>
        (val ? unassignOne(count + 1) : Promise.resolve(count))
      )

    return unassignOne(0).then((returned) => {
      console.log(`ProcessManager: Returned ${returned} accounts assigned to ${identity}.`)
    });
  }

  update() {
    this.ensureCapacity().then(() => {
      console.log(`ProcessManager: Voluntering to sync additional account.`)
      this.acceptUnclaimedAccount().finally(() => {
        this.update();
      });
    })
    .catch((err) => {
      console.log(`ProcessManager: Decided not to sync additional account. ${err.message}`)
      setTimeout(() => this.update(), 5000)
    });
  }

  ensureCapacity() {
    if (os.freemem() < 20 * 1024 * 1024) {
      return Promise.reject(new Error(`<20MB RAM free (${os.freemem()} bytes)`));
    }

    const fiveMinuteLoadAvg = os.loadavg()[1];
    if (fiveMinuteLoadAvg > CPU_COUNT * 0.9) {
      return Promise.reject(new Error(`CPU load > 90% (${fiveMinuteLoadAvg} - ${CPU_COUNT} cores)`));
    }

    if (this._exiting) {
      return Promise.reject(new Error('Process is exiting.'))
    }

    return Promise.resolve();
  }

  acceptUnclaimedAccount() {
    if (!this._waitForAccountClient) {
      this._waitForAccountClient = PubsubConnector.buildClient();
    }

    const src = ACCOUNTS_UNCLAIMED;
    const dst = ACCOUNTS_FOR(IDENTITY);

    return this._waitForAccountClient.brpoplpushAsync(src, dst, 10000).then((accountId) => {
      if (!accountId) { return }
      this.addWorkerForAccountId(accountId);
      setTimeout(() => this.removeWorker(), CLAIM_DURATION);
    });
  }

  addWorkerForAccountId(accountId) {
    DatabaseConnector.forShared().then(({Account}) => {
      Account.find({where: {id: accountId}}).then((account) => {
        if (!account) {
          return;
        }
        DatabaseConnector.forAccount(account.id).then((db) => {
          if (this._exiting) {
            return;
          }
          console.log(`ProcessManager: Starting worker for Account ${accountId}`)
          this._workers[account.id] = new SyncWorker(account, db);
        });
      });
    });
  }

  removeWorker() {
    const src = ACCOUNTS_FOR(IDENTITY);
    const dst = ACCOUNTS_UNCLAIMED;

    return PubsubConnector.broadcastClient().rpoplpushAsync(src, dst).then((accountId) => {
      if (!accountId) {
        return;
      }

      console.log(`ProcessManager: Returning account ${accountId} to unclaimed pool.`)

      if (this._workers[accountId]) {
        this._workers[accountId].cleanup();
      }
      this._workers[accountId] = null;
    });
  }
}

module.exports = SyncProcessManager;
