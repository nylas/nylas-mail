const {Errors: {APIError}} = require('isomorphic-core')
const {SyncbackIMAPTask} = require('./syncback-task')
const SyncTaskFactory = require('../sync-task-factory');

const UNKNOWN_UID_SYNC_BATCH_SIZE = 25;
const NUM_BATCHES_PER_TASK = 20; // 500 messages per task

class SyncUnknownUIDs extends SyncbackIMAPTask {
  description() {
    return `SyncUnknownUIDs`;
  }

  affectsImapMessageUIDs() {
    return false;
  }

  async * _run(db, imap, syncWorker) {
    this._db = db;
    const {Folder} = db
    const {uids, folderId} = this.syncbackRequestObject().props;
    if (!uids || !uids.length) {
      throw new APIError('uids are required');
    }

    if (!folderId) {
      throw new APIError('folderId is required');
    }

    yield this.syncbackRequestObject().update({status: "INPROGRESS-NOTRETRYABLE"});

    const folder = yield Folder.findById(folderId);
    if (!folder) {
      throw new APIError('folder not found', 404);
    }

    if (yield this._isCancelled()) {
      return;
    }

    let remainingUids = uids;
    // We work in smaller batches to reduce the result latency during search.
    for (let i = 0; i < NUM_BATCHES_PER_TASK; ++i) {
      const uidsToSync = remainingUids.slice(0, UNKNOWN_UID_SYNC_BATCH_SIZE);
      this._syncOperation = SyncTaskFactory.create('FetchSpecificMessagesInFolder', {
        account: this._account,
        folder,
        uids: uidsToSync,
      });
      this._syncOperation.on('message-processed', () => this.onMessageProcessed());
      yield this._syncOperation.run(db, imap, syncWorker)
      this._syncOperation.removeAllListeners('message-processed');

      if (yield this._isCancelled()) {
        return;
      }

      remainingUids = remainingUids.slice(UNKNOWN_UID_SYNC_BATCH_SIZE);
      if (remainingUids.length === 0) {
        break;
      }
    }

    // If there are still more UIDs to sync, queue another task to continue syncing.
    // We do this style of chained syncback tasks so that we don't block the
    // sync loop for too long.
    if (remainingUids.length > 0) {
      yield db.SyncbackRequest.create({
        type: "SyncUnknownUIDs",
        props: {folderId, uids: remainingUids},
        accountId: this.syncbackRequestObject().accountId,
      });
    }
  }

  async _isCancelled() {
    if (this._isCancelledCached) {
      return this._isCancelledCached;
    }

    await this.syncbackRequestObject().reload();
    if (this.syncbackRequestObject().status === 'CANCELLED') {
      this._isCancelledCached = true;
      return true;
    }
    return false;
  }

  async onMessageProcessed() {
    if (await this._isCancelled()) {
      await this._syncOperation.interrupt();
    }
  }
}
module.exports = SyncUnknownUIDs
