import {Actions, IdentityStore} from 'nylas-exports'
import {createLogger} from '../../src/shared/logger'
import LocalDatabaseConnector from '../../src/shared/local-database-connector'
import SyncProcessManager from '../../src/local-sync-worker/sync-process-manager'
import SyncActivity from '../../src/shared/sync-activity'

describe("SyncProcessManager", () => {
  beforeEach(async () => {
    global.Logger = createLogger()
    spyOn(IdentityStore, 'identity').andReturn(true)
    const db = await LocalDatabaseConnector.forShared();
    await db.Account.create({id: 'test-account'})
  })
  afterEach(async () => {
    const db = await LocalDatabaseConnector.forShared();
    const accounts = db.Account.findAll();
    return Promise.all(accounts.map((account) => account.destroy()))
  })
  describe("when a sync worker is stuck", () => {
    beforeEach(() => {
      spyOn(Actions, 'recordUserEvent')
      spyOn(SyncProcessManager, 'removeWorkerForAccountId').andCallThrough()
      spyOn(SyncProcessManager, 'addWorkerForAccount').andCallThrough()
      spyOn(SyncActivity, 'getLastSyncActivityForAccount').andReturn({
        time: Date.now() - 2 * SyncProcessManager.MAX_WORKER_SILENCE_MS,
        activity: ['activity'],
      })
      // Make sure the health check interval isn't automatically started
      SyncProcessManager._check_health_interval = 1
    })
    xit("detects it and recovers", async () => {
      await SyncProcessManager.start()
      expect(SyncProcessManager.removeWorkerForAccountId.calls.length).toEqual(0)
      expect(SyncProcessManager.addWorkerForAccount.calls.length).toEqual(1)

      await SyncProcessManager._checkHealth()
      expect(Actions.recordUserEvent.calls.length).toEqual(1)
      expect(SyncProcessManager.removeWorkerForAccountId.calls.length).toEqual(1)
      expect(SyncProcessManager.addWorkerForAccount.calls.length).toEqual(2)
    })
    xit("doesn't have zombie workers come back to life", async () => {
      await SyncProcessManager.start()

      // Zombify a worker
      const zombieSync = () => {
        return new Promise(() => {}) // Never resolves
      }
      const zombieWorker = SyncProcessManager.workers()[0]
      const origSync = zombieWorker.syncNow
      zombieWorker.syncNow = zombieSync
      zombieWorker.interrupt()
      zombieWorker.syncNow()

      // Make sure the worker is discarded by the manager
      await SyncProcessManager._checkHealth()
      expect(Actions.recordUserEvent.calls.length).toEqual(1)
      expect(SyncProcessManager.removeWorkerForAccountId.calls.length).toEqual(1)
      expect(SyncProcessManager.addWorkerForAccount.calls.length).toEqual(2)

      // Try to get the zombie to sync again, check that it doesn't.
      const lastStart = zombieWorker._syncStart;
      zombieWorker.syncNow = origSync
      zombieWorker.interrupt({reason: 'Playing Frankenstein'})
      await zombieWorker.syncNow()
      expect(zombieWorker._syncStart).toEqual(lastStart)
    })
  })
})
