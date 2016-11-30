const SyncbackTask = require('./syncback-task')

class SaveSentMessageIMAP extends SyncbackTask {
  description() {
    return `SaveSentMessage`;
  }

  async run(db, imap) {
    // TODO: gmail doesn't have a sent folder
    const folder = await db.Folder.find({where: {role: 'sent'}});
    const box = await imap.openBox(folder.name);
    return box.append(this.syncbackRequestObject().props.rawMime);
  }
}
module.exports = SaveSentMessageIMAP;
