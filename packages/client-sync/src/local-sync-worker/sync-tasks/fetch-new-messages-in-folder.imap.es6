const FetchMessagesInFolderIMAP = require('./fetch-messages-in-folder.imap')


// TODO Eventually make FetchMessagesInFolderIMAP use this class and split it up
// into smaller parts (not a fan of the multi level inheritance tree)

/**
 * This sync task will only fetch /new/ messages in a folder
 */
class FetchNewMessagesInFolderIMAP extends FetchMessagesInFolderIMAP {

  description() {
    return `FetchNewMessagesInFolderIMAP (${this._folder.name} - ${this._folder.id})`;
  }

  async * runTask(db, imap, syncWorker) {
    this._logger.log(`🔜 📂 🆕  ${this._folder.name} - Looking for new messages`)
    this._db = db;
    this._imap = imap;
    if (!syncWorker) {
      throw new Error(`SyncWorker not passed to runTask`);
    }
    this._syncWorker = syncWorker;
    const {syncState: {fetchedmax}} = this._folder

    if (!fetchedmax) {
      // Without a fetchedmax, can't tell what's new!
      // If we haven't fetched anything on this folder, let's run a normal fetch
      // operation
      // Can't use `super` in this scenario because babel can't compile it under
      // these conditions. User regular prototype instead
      this._logger.log(`🔚 📂 🆕  ${this._folder.name} has no fetchedmax - running regular fetch operation`)
      yield FetchMessagesInFolderIMAP.prototype.runTask.call(this, db, imap, syncWorker)
      return
    }

    const latestBoxStatus = yield this._imap.getLatestBoxStatus(this._folder.name)
    if (latestBoxStatus.uidnext > fetchedmax) {
      this._box = await this._imap.openBox(this._folder.name)
      const boxUidnext = this._box.uidnext
      yield this._fetchAndProcessMessages({min: fetchedmax, max: boxUidnext});
    } else {
      this._logger.log(`🔚 📂 🆕  ${this._folder.name} has no new messages - skipping fetch messages`)
    }
    this._logger.log(`🔚 📂 🆕  ${this._folder.name} done`)
  }
}

module.exports = FetchNewMessagesInFolderIMAP;
