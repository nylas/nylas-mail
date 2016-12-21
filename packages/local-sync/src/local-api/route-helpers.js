const Serialization = require('./serialization');
const SyncProcessManager = require('../local-sync-worker/sync-process-manager')

module.exports = {
  async createSyncbackRequest(request, reply, syncRequestArgs = {}) {
    const account = request.auth.credentials
    const {syncbackImmediately} = syncRequestArgs
    syncRequestArgs.accountId = account.id

    const db = await request.getAccountDatabase()
    const syncbackRequest = await db.SyncbackRequest.create(syncRequestArgs)

    const priority = syncbackImmediately ? 10 : 1;
    SyncProcessManager.wakeWorkerForAccount(account.id, {priority})
    reply(Serialization.jsonStringify(syncbackRequest))
  },
}
