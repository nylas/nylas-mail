const Serialization = require('./serialization');
const SyncProcessManager = require('../local-sync-worker/sync-process-manager')

module.exports = {
  async createSyncbackRequest(request, reply, syncRequestArgs = {}) {
    const account = request.auth.credentials
    const {syncbackImmediately = false} = syncRequestArgs
    syncRequestArgs.accountId = account.id

    const db = await request.getAccountDatabase()
    const syncbackRequest = await db.SyncbackRequest.create(syncRequestArgs)

    SyncProcessManager.wakeWorkerForAccount(account.id, {interrupt: syncbackImmediately})
    reply(Serialization.jsonStringify(syncbackRequest))
  },
}
