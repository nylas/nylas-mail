const {Errors: {APIError}} = require('isomorphic-core')
const {SyncbackIMAPTask} = require('./syncback-task')
const SyncTaskFactory = require('../sync-task-factory');

class SyncUnknownUIDs extends SyncbackIMAPTask {
  description() {
    return `SyncUnknownUIDs`;
  }

  affectsImapMessageUIDs() {
    return false;
  }

  async run(db, imap, syncWorker) {
    this._db = db;
    const {Folder} = db
    const {uids, folderId} = this.syncbackRequestObject().props;
    if (!uids || !uids.length) {
      throw new APIError('uids are required');
    }

    if (!folderId) {
      throw new APIError('folderId is required');
    }

    await this.syncbackRequestObject().update({status: "INPROGRESS-NOTRETRYABLE"});

    const folder = await Folder.findById(folderId);
    if (!folder) {
      throw new APIError('folder not found', 404);
    }

    this._syncOperation = SyncTaskFactory.create('FetchSpecificMessagesInFolder', {
      account: this._account,
      folder,
      uids,
    });
    this._syncOperation.on('message-processed', () => this.onMessageProcessed());
    await this._syncOperation.run(db, imap, syncWorker)
  }

  async onMessageProcessed() {
    await this.syncbackRequestObject().reload();
    if (this.syncbackRequestObject().status === 'CANCELLED') {
      await this._syncOperation.interrupt();
    }
  }
}
module.exports = SyncUnknownUIDs
