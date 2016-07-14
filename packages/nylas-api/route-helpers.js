const Serialization = require('./serialization');
const {PromiseUtils, PubsubConnector, MessageTypes} = require('nylas-core')

module.exports = {
  createSyncbackRequest: function createSyncbackRequest(request, reply, syncRequestArgs) {
    request.getAccountDatabase().then((db) => {
      db.SyncbackRequest.create(syncRequestArgs).then((syncbackRequest) => {
        PubsubConnector.notifyAccount(db.accountId, {
          type: MessageTypes.SYNCBACK_REQUESTED,
          data: syncbackRequest.id,
        });
        reply(Serialization.jsonStringify(syncbackRequest))
      })
    })
  },
  findFolderOrLabel: function findFolderOrLabel({Folder, Label}, str) {
    return PromiseUtils.props({
      folder: Folder.find({
        where: { $or: [
          { id: str },
          { name: str },
          { role: str },
        ]},
      }),
      label: Label.find({
        where: { $or: [
          { id: str },
          { name: str },
          { role: str },
        ]},
      }),
    }).then(({folder, label}) =>
      folder || label || null
    )
  },
}
