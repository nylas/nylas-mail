const _ = require('underscore')
const fs = require('fs')
const {remote} = require('electron')
const {Actions} = require('nylas-exports')
const SyncWorker = require('./sync-worker');
const LocalDatabaseConnector = require('../shared/local-database-connector')


class SyncProcessManager {
  constructor() {
    this._workers = {};
    this._exiting = false;
    this._accounts = []

    Actions.wakeLocalSyncWorkerForAccount.listen((accountId) =>
      this.wakeWorkerForAccount(accountId, {interrupt: true})
    );
    this._resettingEmailCache = false
    Actions.resetEmailCache.listen(this._resetEmailCache, this)
    Actions.debugSync.listen(this._onDebugSync)
  }

  _onDebugSync() {
    const win = NylasEnv.getCurrentWindow()
    win.show()
    win.maximize()
    win.openDevTools()
  }

  _resetEmailCache() {
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
        for (const account of this.accounts()) {
          LocalDatabaseConnector.destroyAccountDatabase(account.id)
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

  accounts() { return this._accounts }
  workers() { return _.values(this._workers) }
  dbs() { return this.workers().map(w => w._db) }

  wakeWorkerForAccount(accountId, {reason = 'Waking sync', interrupt} = {}) {
    const worker = this._workers[accountId]
    if (worker) {
      worker.syncNow({reason, interrupt});
    }
  }

  async addWorkerForAccount(account) {
    await LocalDatabaseConnector.ensureAccountDatabase(account.id);
    const logger = global.Logger.forAccount(account)

    try {
      const db = await LocalDatabaseConnector.forAccount(account.id);
      if (this._workers[account.id]) {
        logger.warn(`SyncProcessManager: Worker for account already exists`)
        return
      }
      this._accounts.push(account)
      this._workers[account.id] = new SyncWorker(account, db, this);
      logger.log(`SyncProcessManager: Claiming Account Succeeded`)
    } catch (err) {
      logger.error(`SyncProcessManager: Claiming Account Failed`, err)
    }
  }

  async removeWorkerForAccountId(accountId) {
    if (this._workers[accountId]) {
      await this._workers[accountId].cleanup();
      this._workers[accountId] = null;
    }
  }
}

window.syncProcessManager = new SyncProcessManager();
window.dbs = window.syncProcessManager.dbs.bind(window.syncProcessManager)
module.exports = window.syncProcessManager
