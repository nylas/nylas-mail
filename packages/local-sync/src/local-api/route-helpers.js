const Serialization = require('./serialization');

module.exports = {
  createSyncbackRequest: function createSyncbackRequest(request, reply, syncRequestArgs) {
    request.getAccountDatabase().then((db) => {
      const accountId = request.auth.credentials.id;
      syncRequestArgs.accountId = accountId
      db.SyncbackRequest.create(syncRequestArgs).then((syncbackRequest) => {
        reply(Serialization.jsonStringify(syncbackRequest))
      })
    })
  },
}
