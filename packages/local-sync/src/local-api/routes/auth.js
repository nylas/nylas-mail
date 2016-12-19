const { AuthHelpers } = require('isomorphic-core');
const DefaultSyncPolicy = require('../default-sync-policy')
const LocalDatabaseConnector = require('../../shared/local-database-connector')
const SyncProcessManager = require('../../local-sync-worker/sync-process-manager')

const upsertAccount = (accountParams, credentials) => {
  return LocalDatabaseConnector.forShared().then(({Account}) => {
    accountParams.syncPolicy = DefaultSyncPolicy
    accountParams.lastSyncCompletions = []

    return Account.upsertWithCredentials(accountParams, credentials)
    .then(({account, token}) => {
      SyncProcessManager.addWorkerForAccount(account)
      return {account, token}
    })
  });
}

module.exports = (server) => {
  server.route({
    method: 'POST',
    path: '/auth',
    config: AuthHelpers.imapAuthRouteConfig(),
    handler: AuthHelpers.imapAuthHandler(upsertAccount),
  });
}
