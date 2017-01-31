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
    const {syncState: {fetchedmax}} = this._folder

    if (!fetchedmax) {
      // Without a fetchedmax, can't tell what's new!
      // If we haven't fetched anything on this folder, let's run a normal fetch
      // operation
      // Can't use `super` in this scenario because babel can't compile it under
      // these conditions. User regular prototype instead
      console.log(`🔚 📂  🆕 ${this._folder.name} has no fetchedmax - running regular fetch operation`)
      yield FetchMessagesInFolderIMAP.prototype.runTask.call(this, db, imap)
      return
    }

    const latestBoxStatus = yield this._imap.getLatestBoxStatus(this._folder.name)
    if (latestBoxStatus.uidnext > fetchedmax) {
      this._box = await this._imap.openBox(this._folder.name)
      const boxUidnext = this._box.uidnext
      yield this._fetchAndProcessMessages({min: fetchedmax, max: boxUidnext});
    } else {
      console.log(`🔚 📂  🆕$ {this._folder.name} has no new messages - skipping fetch messages`)
    }
    console.log(`🔚 📂 ${this._folder.name} done`)
  }
}

module.exports = FetchNewMessagesInFolderIMAP;


// boo hoo
