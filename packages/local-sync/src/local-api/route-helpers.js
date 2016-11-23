const Serialization = require('./serialization');
const LocalPubsubConnector = require('../shared/local-pubsub-connector')
const MessageTypes = require('../shared/message-types')

module.exports = {
  createSyncbackRequest: function createSyncbackRequest(request, reply, syncRequestArgs) {
    request.getAccountDatabase().then((db) => {
      db.SyncbackRequest.create(syncRequestArgs).then((syncbackRequest) => {
        LocalPubsubConnector.notifyAccount(db.accountId, {
          type: MessageTypes.SYNCBACK_REQUESTED,
          data: syncbackRequest.id,
        });
        reply(Serialization.jsonStringify(syncbackRequest))
      })
    })
  },
}
