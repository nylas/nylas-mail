const { AuthHelpers } = require('isomorphic-core');
const DefaultSyncPolicy = require('../default-sync-policy')
const LocalDatabaseConnector = require('../../shared/local-database-connector')
const SyncProcessManager = require('../../local-sync-worker/sync-process-manager')

async function upsertAccount(accountParams, credentials) {
  accountParams.syncPolicy = DefaultSyncPolicy
  accountParams.lastSyncCompletions = []
  const db = await LocalDatabaseConnector.forShared()
  const {account, token} = await db.Account.upsertWithCredentials(accountParams, credentials)
  SyncProcessManager.addWorkerForAccount(account)
  return {account, token}
}

module.exports = (server) => {
  server.route({
    method: 'POST',
    path: '/auth',
    config: AuthHelpers.imapAuthRouteConfig(),
    handler: AuthHelpers.imapAuthHandler(upsertAccount),
  });
}
