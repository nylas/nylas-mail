const _ = require('underscore')
const fs = require('fs')
const {remote} = require('electron')
const {Actions, OnlineStatusStore} = require('nylas-exports')
const SyncWorker = require('./sync-worker');
const LocalSyncDeltaEmitter = require('./local-sync-delta-emitter').default
const LocalDatabaseConnector = require('../shared/local-database-connector')


class SyncProcessManager {
  constructor() {
    this._exiting = false;
    this._resettingEmailCache = false
    this._workersByAccountId = {};
    this._localSyncDeltaEmittersByAccountId = new Map()

    OnlineStatusStore.listen(this._onOnlineStatusChanged, this)
    Actions.resetEmailCache.listen(this._resetEmailCache, this)
    Actions.debugSync.listen(this._onDebugSync, this)
    Actions.wakeLocalSyncWorkerForAccount.listen((accountId) =>
      this.wakeWorkerForAccount(accountId, {interrupt: true})
    );
  }

  _onOnlineStatusChanged() {
    if (OnlineStatusStore.isOnline()) {
      Object.keys(this._workersByAccountId).forEach((id) => {
        this.wakeWorkerForAccount(id, {reason: 'Came back online'})
      })
    }
  }

  _onDebugSync() {
    const win = NylasEnv.getCurrentWindow()
    win.show()
    win.maximize()
    win.openDevTools()
  }

  async _resetEmailCache() {
    if (this._resettingEmailCache) return;
    this._resettingEmailCache = true
    try {
      for (const worker of this.workers()) {
        worker.stopSync()
      }
      setTimeout(async () => {
        // Give the sync a chance to stop first before killing the whole
        // DB
        fs.unlinkSync(`${NylasEnv.getConfigDirPath()}/edgehill.db`)
        for (const accountId of Object.keys(this._workersByAccountId)) {
          await LocalDatabaseConnector.destroyAccountDatabase(accountId)
        }
        remote.app.relaunch()
        remote.app.quit()
      }, 100)
    } catch (err) {
      global.Logger.error('Error resetting email cache', err)
      this._resettingEmailCache = false
    }
  }

  /**
   * Useful for debugging.
   */
  async start() {
    global.Logger.log(`SyncProcessManager: Starting sync`)

    const {Account} = await LocalDatabaseConnector.forShared();
    const accounts = await Account.findAll();
    for (const account of accounts) {
      this.addWorkerForAccount(account);
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

  async addWorkerForAccount(account) {
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
      await this._workersByAccountId[accountId].cleanup();
      this._workersByAccountId[accountId] = null;
    }

    if (this._localSyncDeltaEmittersByAccountId.has(accountId)) {
      this._localSyncDeltaEmittersByAccountId.get(accountId).deactivate();
      this._localSyncDeltaEmittersByAccountId.delete(accountId)
    }
  }
}

window.$n.SyncProcessManager = new SyncProcessManager();
module.exports = window.$n.SyncProcessManager
