const _ = require('underscore')
const Serialization = require('./serialization');
const SyncProcessManager = require('../local-sync-worker/sync-process-manager')


const wakeSyncWorker = _.debounce((accountId, reason) => {
  SyncProcessManager.wakeWorkerForAccount(accountId, {interrupt: true, reason})
}, 500)

module.exports = {
  async createAndReplyWithSyncbackRequest(request, reply, syncRequestArgs = {}) {
    const account = request.auth.credentials
    const {wakeSync = true} = syncRequestArgs
    syncRequestArgs.accountId = account.id

    const db = await request.getAccountDatabase()
    const syncbackRequest = await db.SyncbackRequest.create(syncRequestArgs)

    if (wakeSync) {
      wakeSyncWorker(account.id, `Need to run task ${syncbackRequest.type}`)
    }
    reply(Serialization.jsonStringify(syncbackRequest))
    return syncbackRequest
  },
}
