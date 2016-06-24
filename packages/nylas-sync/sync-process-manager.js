const os = require('os');
const SyncWorker = require('./sync-worker');
const {DatabaseConnector, PubsubConnector, SchedulerUtils} = require(`nylas-core`)

const IDENTITY = `${os.hostname()}-${process.pid}`;

const {
  ACCOUNTS_FOR,
  ACCOUNTS_UNCLAIMED,
  ACCOUNTS_CLAIMED_PREFIX,
  HEARTBEAT_FOR,
  HEARTBEAT_EXPIRES,
  CLAIM_DURATION,
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
      console.log("ProcessManager: ❤")
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

    console.log("ProcessManager: Starting scan for accountIds in database that are not present in Redis.")

    return forEachAccountList((foundProcessIdentity, foundIds) => {
      unseenIds = unseenIds.filter((a) => !foundIds.includes(`${a}`))
    })
    .finally(() => {
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
    console.log(`ProcessManager: Searching for an unclaimed account to sync.`)

    this.acceptUnclaimedAccount().finally(() => {
      if (this._exiting) {
        return;
      }
      this.update();
    });
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
        if (!account || this._workers[account.id]) {
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
