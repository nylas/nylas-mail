const SyncbackTask = require('./syncback-task')

class SaveSentMessageIMAP extends SyncbackTask {
  description() {
    return `SaveSentMessage`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const {rawMime, headerMessageId} = this.syncbackRequestObject().props;

    // Non-gmail
    const sentFolder = await db.Folder.find({where: {role: 'sent'}});
    if (sentFolder) {
      const box = await imap.openBox(sentFolder.name);
      return box.append(rawMime);
    }

    // Gmail, we need to add the message to all mail and add the sent label
    const sentLabel = await db.Label.find({where: {role: 'sent'}});
    const allMail = await db.Folder.find({where: {role: 'all'}});
    if (sentLabel && allMail) {
      const box = await imap.openBox(allMail.name);
      await box.append(rawMime, {flags: 'SEEN'})
      const uids = await box.search([['HEADER', 'Message-ID', headerMessageId]])
      // There should only be one uid in the array
      return box.setLabels(uids[0], '\\Sent');
    }

    throw new Error('Could not save message to sent folder.')
  }
}

module.exports = SaveSentMessageIMAP;
