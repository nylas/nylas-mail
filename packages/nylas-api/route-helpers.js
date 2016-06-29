const Serialization = require('./serialization');
const {PubsubConnector, MessageTypes} = require('nylas-core')

module.exports = {
  createSyncbackRequest: function createSyncbackRequest(request, reply, syncRequestArgs) {
    request.getAccountDatabase().then((db) => {
      db.SyncbackRequest.create(syncRequestArgs).then((syncbackRequest) => {
        console.log("Created syncbackrequest")
        console.log(syncbackRequest.props)
        console.log("PubsubConnector.notify")
        PubsubConnector.notify({
          accountId: db.accountId,
          type: MessageTypes.SYNCBACK_REQUESTED,
          data: syncbackRequest.id,
        });
        reply(Serialization.jsonStringify(syncbackRequest))
      })
    })
  },
}
