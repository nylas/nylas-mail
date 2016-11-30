const SyncbackTask = require('./syncback-task')

class PermanentlyDeleteMessageIMAP extends SyncbackTask {
  description() {
    return `PermanentlyDeleteMessage`;
  }

  async run(db, imap) {
    const messageId = this.syncbackRequestObject().props.messageId
    const message = await db.Message.findById(messageId);
    const folder = await db.Folder.findById(message.folderId);
    const box = await imap.openBox(folder.name);
    const result = await box.addFlags(message.folderImapUID, 'DELETED');
    return result;

    // TODO: We need to also delete the message from the trash
    // if (folder.role === 'trash') { return result; }
    //
    // const trash = await db.Folder.find({where: {role: 'trash'}});
    // const trashBox = await imap.openBox(trash.name);
    // return await trashBox.addFlags(message.folderImapUID, 'DELETED');
  }
}
module.exports = PermanentlyDeleteMessageIMAP;
