import _ from 'underscore'
import Boom from 'boom';
import Serialization from './serialization';
import SyncProcessManager from '../local-sync-worker/sync-process-manager'


const wakeSyncWorker = _.debounce((accountId, reason) => {
  SyncProcessManager.wakeWorkerForAccount(accountId, {interrupt: true, reason})
}, 500)

export async function createAndReplyWithSyncbackRequest(request, reply, syncRequestArgs = {}) {
  try {
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
  } catch (err) {
    reply(Boom.wrap(err))
    return null
  }
}
