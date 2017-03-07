const FetchMessagesInFolderIMAP = require('./fetch-messages-in-folder.imap')

/*
 * This sync task will only fetch the specified set of UIDs
 */
class FetchSpecificMessagesInFolderIMAP extends FetchMessagesInFolderIMAP {
  description() {
    return `FetchSpecificMessagesInFolderIMAP (${this._folder.name} - ${this._folder.id})`;
  }

  async * runTask(db, imap, syncWorker) {
    this._logger.log(`🔜 📂 🆕  ${this._folder.name} - Looking for ${this._uids.length} specific UIDs`);
    this._db = db;
    this._imap = imap;
    if (!syncWorker) {
      throw new Error(`SyncWorker not passed to runTask`);
    }
    this._syncWorker = syncWorker;
    const {syncState: {fetchedmin, fetchedmax}} = this._folder;

    let uids = this._uids;
    if (fetchedmin && fetchedmax) {
      uids = uids.filter(uid => uid < fetchedmin || uid > fetchedmax);
    }

    if (uids.length === 0) {
      this._logger.log(`🔜 📂 🆕  ${this._folder.name} - Already fetched all UIDs`);
      return;
    }

    this._logger.log(`🔜 📂 🆕  ${this._folder.name} - Fetching ${uids.length} UIDs`);
    this._box = await this._imap.openBox(this._folder.name)
    yield this._fetchAndProcessMessages({uids, throttle: false});
    this._logger.log(`🔚 📂 🆕  ${this._folder.name} done`);
  }
}

module.exports = FetchSpecificMessagesInFolderIMAP;
