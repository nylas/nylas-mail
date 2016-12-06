const SyncbackTask = require('./syncback-task')

class DeleteSentMessageGMAIL extends SyncbackTask {
  description() {
    return `DeleteSentMessage`;
  }

  affectsImapMessageUIDs() {
    return true
  }

  async run(db, imap) {
    const {messageId} = this.syncbackRequestObject().props

    const trash = await db.Folder.find({where: {role: 'trash'}});
    if (!trash) { throw new Error(`Could not find folder with role 'trash'.`) }

    const allMail = await db.Folder.find({where: {role: 'all'}});
    if (!allMail) { throw new Error(`Could not find folder with role 'all'.`) }

    // Move the message from all mail to trash and then delete it from there
    const steps = [
      {folder: allMail, deleteFn: (box, uid) => box.moveFromBox(uid, trash.name)},
      {folder: trash, deleteFn: (box, uid) => box.addFlags(uid, 'DELETED')},
    ]

    for (const {folder, deleteFn} of steps) {
      const box = await imap.openBox(folder.name);
      const uids = await box.search([['HEADER', 'Message-ID', messageId]])
      for (const uid of uids) {
        await deleteFn(box, uid);
      }
      box.closeBox();
    }
  }
}
module.exports = DeleteSentMessageGMAIL;
