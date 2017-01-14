const Serialization = require('./serialization');
const SyncProcessManager = require('../local-sync-worker/sync-process-manager')

module.exports = {
  async createAndReplyWithSyncbackRequest(request, reply, syncRequestArgs = {}) {
    const account = request.auth.credentials
    const {syncbackImmediately = false, wakeSync = true} = syncRequestArgs
    syncRequestArgs.accountId = account.id

    const db = await request.getAccountDatabase()
    const syncbackRequest = await db.SyncbackRequest.create(syncRequestArgs)

    if (wakeSync) {
      SyncProcessManager.wakeWorkerForAccount(account.id, {interrupt: syncbackImmediately})
    }
    reply(Serialization.jsonStringify(syncbackRequest))
    return syncbackRequest
  },
}
