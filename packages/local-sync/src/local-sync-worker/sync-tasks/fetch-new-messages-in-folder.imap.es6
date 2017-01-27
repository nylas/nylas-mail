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

  async * runTask(db, imap) {
    console.log(`🔜 📂  🆕  Looking for new messages in ${this._folder.name}`)
    this._db = db;
    this._imap = imap;

    this._box = await this._imap.openBox(this._folder.name)

    if (this._shouldFetchMessages(this._box)) {
      const boxUidnext = this._box.uidnext
      const {syncState: {fetchedmax}} = this._folder
      yield this._fetchAndProcessMessages({min: fetchedmax, max: boxUidnext});
    } else {
      console.log(`🔚 📂 ${this._folder.name} has no new messages - skipping fetch messages`)
    }
    console.log(`🔚 📂 ${this._folder.name} done`)
  }
}

module.exports = FetchNewMessagesInFolderIMAP;


// boo hoo
