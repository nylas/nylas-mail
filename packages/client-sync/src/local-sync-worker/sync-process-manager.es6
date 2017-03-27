const _ = require('underscore')
const {ipcRenderer} = require('electron')
const {Actions, OnlineStatusStore, IdentityStore} = require('nylas-exports')
const SyncWorker = require('./sync-worker');
const LocalSyncDeltaEmitter = require('./local-sync-delta-emitter').default
const LocalDatabaseConnector = require('../shared/local-database-connector')
const SyncActivity = require('../shared/sync-activity').default

const MAX_WORKER_SILENCE_MS = Math.max(
  SyncWorker.AC_SYNC_LOOP_INTERVAL_MS,
  SyncWorker.BATTERY_SYNC_LOOP_INTERVAL_MS,
  SyncWorker.MAX_SYNC_BACKOFF_MS,
)
const CHECK_HEALTH_TIME_INTERVAL = 1 * 60 * 1000

class SyncProcessManager {
  constructor() {
    this._exiting = false;
    this._resettingEmailCache = false
    this._identityId = null;
    this._workersByAccountId = {};
    this._localSyncDeltaEmittersByAccountId = new Map()

    OnlineStatusStore.listen(this._onOnlineStatusChanged, this)
    IdentityStore.listen(this._onIdentityChanged, this)
    Actions.resetEmailCache.listen(this._resetEmailCache, this)
    Actions.debugSync.listen(this._onDebugSync, this)
    Actions.wakeLocalSyncWorkerForAccount.listen((accountId) =>
      this.wakeWorkerForAccount(accountId, {interrupt: true})
    );
    ipcRenderer.on('app-resumed-from-sleep', () => {
      this._wakeAllWorkers({reason: 'Computer resumed from sleep', interrupt: true})
    })

    this._checkHealthInterval = null;
  }

  _onOnlineStatusChanged() {
    if (OnlineStatusStore.isOnline()) {
      this._wakeAllWorkers({reason: 'Came back online', interrupt: true})
    }
  }

  _onIdentityChanged() {
    const newIdentityId = IdentityStore.identityId()
    if (newIdentityId !== this._identityId) {
      // The IdentityStore can trigger any number of times, but we only want to
      // start sync if we previously didn't have an identity available
      this._identityId = newIdentityId
      this.start()
    }
  }

  _onDebugSync() {
    const win = NylasEnv.getCurrentWindow()
    win.show()
    win.maximize()
    win.openDevTools()
  }

  _wakeAllWorkers({reason, interrupt} = {}) {
    Object.keys(this._workersByAccountId).forEach((id) => {
      this.wakeWorkerForAccount(id, {reason, interrupt})
    })
  }

  async _resetEmailCache() {
    if (this._resettingEmailCache) return;
    this._resettingEmailCache = true
    try {
      try {
        await Promise.all(
          this.workers().map(w => w.stopSync())
        )
        .timeout(500, 'Timed out while trying to stop sync')
      } catch (err) {
        global.Logger.warn('SyncProcessManager._resetEmailCache: Error while stopping sync', err)
      }
      const accountIds = Object.keys(this._workersByAccountId)
      for (const accountId of accountIds) {
        await LocalDatabaseConnector.destroyAccountDatabase(accountId)
      }

      ipcRenderer.send('command', 'application:relaunch-to-initial-windows', {
        resetDatabase: true,
      })
    } catch (err) {
      global.Logger.error('Error resetting email cache', err)
    } finally {
      this._resettingEmailCache = false
    }
  }

  _checkHealthByAccountId = async (accountId) => {
    const {time, activity} = SyncActivity.getLastSyncActivityForAccount(accountId);
    if (time < Date.now() - this.MAX_WORKER_SILENCE_MS) {
      const duration = Date.now() - time;
      NylasEnv.reportError(new Error("SyncProcessManager: Detected stuck sync process"), {
        rateLimit: {
          ratePerHour: 30,
          key: `SyncProcessManager:StuckProcess`,
        },
      })
      Actions.recordUserEvent('Stuck Sync Process', {
        accountId: accountId,
        lastActivityTime: time,
        lastActivity: activity,
        duration,
      })
      global.Logger.log(`SyncProcessManager: Detected stuck worker for account ${accountId}`, activity, time)

      await this.removeWorkerForAccountId(accountId)
      const {Account} = await LocalDatabaseConnector.forShared();
      const account = await Account.findById(accountId)
      await this.addWorkerForAccount(account)
    }
  }

  _checkHealth = async () => {
    return Promise.all(Object.keys(this._workersByAccountId).map(this._checkHealthByAccountId))
  }

  /**
   * Useful for debugging.
   */
  async start() {
    if (!IdentityStore.identity()) {
      global.Logger.log(`SyncProcessManager: Can't start sync; no Nylas Identity present`)
      return
    }
    global.Logger.log(`SyncProcessManager: Starting sync`)

    const {Account} = await LocalDatabaseConnector.forShared();
    const accounts = await Account.findAll();
    await Promise.all(accounts.map(this.addWorkerForAccount));

    if (!this._checkHealthInterval) {
      this._checkHealthInterval = setInterval(this._checkHealth, this.CHECK_HEALTH_TIME_INTERVAL)
    }
  }

  workers() {
    return _.values(this._workersByAccountId)
  }

  dbs() {
    return this.workers().map(w => w._db)
  }

  wakeWorkerForAccount(accountId, {reason = 'Waking sync', interrupt} = {}) {
    const worker = this._workersByAccountId[accountId]
    if (worker) {
      worker.syncNow({reason, interrupt});
    }
  }

  addWorkerForAccount = async (account) => {
    await LocalDatabaseConnector.ensureAccountDatabase(account.id);
    const logger = global.Logger.forAccount(account)

    try {
      if (this._workersByAccountId[account.id]) {
        logger.warn(`SyncProcessManager.addWorkerForAccount: Worker for account already exists - skipping`)
        return
      }
      const db = await LocalDatabaseConnector.forAccount(account.id);
      this._workersByAccountId[account.id] = new SyncWorker(account, db, this);

      const localSyncDeltaEmitter = new LocalSyncDeltaEmitter(account, db)
      await localSyncDeltaEmitter.activate()
      this._localSyncDeltaEmittersByAccountId.set(account.id, localSyncDeltaEmitter)
      logger.log(`SyncProcessManager: Claiming Account Succeeded`)
    } catch (err) {
      logger.error(`SyncProcessManager: Claiming Account Failed`, err)
    }
  }

  async removeWorkerForAccountId(accountId) {
    if (this._workersByAccountId[accountId]) {
      try {
        await this._workersByAccountId[accountId].cleanup().timeout(500)
      } catch (err) {
        err.message = `Error while cleaning up sync worker: ${err.message}`
        NylasEnv.reportError(err)
        // Continue with local cleanup
      }
      this._workersByAccountId[accountId] = null;
    }

    if (this._localSyncDeltaEmittersByAccountId.has(accountId)) {
      this._localSyncDeltaEmittersByAccountId.get(accountId).deactivate();
      this._localSyncDeltaEmittersByAccountId.delete(accountId)
    }
  }
}

window.$n.SyncProcessManager = new SyncProcessManager();
window.$n.SyncProcessManager.MAX_WORKER_SILENCE_MS = MAX_WORKER_SILENCE_MS
window.$n.SyncProcessManager.CHECK_HEALTH_TIME_INTERVAL = CHECK_HEALTH_TIME_INTERVAL

module.exports = window.$n.SyncProcessManager
