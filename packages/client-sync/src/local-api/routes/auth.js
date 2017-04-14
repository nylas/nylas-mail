const { AuthHelpers } = require('isomorphic-core');
const DefaultSyncPolicy = require('../default-sync-policy')
const LocalDatabaseConnector = require('../../shared/local-database-connector')
const SyncProcessManager = require('../../local-sync-worker/sync-process-manager')
const {preventCreationOfDuplicateAccounts} = require('../../shared/dedupe-accounts')

async function upsertAccount(accountParams, credentials) {
  accountParams.syncPolicy = DefaultSyncPolicy
  accountParams.lastSyncCompletions = []
  const db = await LocalDatabaseConnector.forShared()

  // NOTE: See https://phab.nylas.com/D4425 for explanation of why this check
  // is necessary
  // TODO remove this check after it no longer affects users
  await preventCreationOfDuplicateAccounts(db, accountParams)

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
