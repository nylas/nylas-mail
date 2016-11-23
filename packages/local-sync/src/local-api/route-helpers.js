const Serialization = require('./serialization');

module.exports = {
  createSyncbackRequest: function createSyncbackRequest(request, reply, syncRequestArgs) {
    request.getAccountDatabase().then((db) => {
      db.SyncbackRequest.create(syncRequestArgs).then((syncbackRequest) => {
        reply(Serialization.jsonStringify(syncbackRequest))
      })
    })
  },
}
