const {
  Provider,
  Errors: {APIError},
  MessageUtils: {getReplyHeaders, buildMime},
} = require('isomorphic-core')
const {SyncbackIMAPTask} = require('./syncback-task')
const SyncTaskFactory = require('../sync-task-factory');


async function* deleteGmailSentMessages({db, imap, provider, headerMessageId}) {
  if (provider !== 'gmail') { return }

  const trash = yield db.Folder.find({where: {role: 'trash'}});
  if (!trash) { throw new APIError(`Could not find folder with role 'trash'.`) }

  const allMail = yield db.Folder.find({where: {role: 'all'}});
  if (!allMail) { throw new APIError(`Could not find folder with role 'all'.`) }

  // Move the message from all mail to trash and then delete it from there
  const steps = [
    {folder: allMail, deleteFn: (box, uid) => box.moveFromBox(uid, trash.name)},
    {folder: trash, deleteFn: (box, uid) => box.addFlags(uid, 'DELETED')},
  ]

  for (const {folder, deleteFn} of steps) {
    const box = yield imap.openBox(folder.name);
    const uids = yield box.search([['HEADER', 'Message-ID', headerMessageId]])
    for (const uid of uids) {
      yield deleteFn(box, uid);
    }
    yield box.closeBox();
  }
}

async function* saveSentMessage({db, account, syncWorker, logger, imap, provider, customSentMessage, baseMessage}) {
  const {Folder, Label} = db

  // Case 1. If non gmail, save the message to the `sent` folder using IMAP
  // Only gmail creates a sent message for us, so if we are using any other provider
  // we need to save it manually ourselves.
  if (provider !== 'gmail') {
    const sentFolder = yield Folder.find({where: {role: 'sent'}});
    if (!sentFolder) { throw new APIError(`Can't find sent folder - could not save message to sent folder.`) }

    const rawMime = yield buildMime(baseMessage, {includeBcc: true});
    const box = yield imap.openBox(sentFolder.name);
    yield box.append(rawMime, {flags: 'SEEN'});

    // If IMAP succeeds, fetch any new messages in the sent folder which
    // should include the messages we just created there
    // The sync operation will save the changes to the database.
    // TODO add transaction
    const syncOperation = SyncTaskFactory.create('FetchNewMessagesInFolder', {
      account,
      folder: sentFolder,
    })
    yield syncOperation.run(db, imap, {syncWorker})
    return
  }


  // Showing as sent in gmail means adding the message to all mail and
  // adding the sent label
  const sentLabel = yield Label.find({where: {role: 'sent'}});
  const allMailFolder = yield Folder.find({where: {role: 'all'}});
  if (!sentLabel || !allMailFolder) {
    throw new APIError('Could not save message to sent folder.')
  }


  // Case 2. If gmail, even though gmail saves sent messages automatically,
  // if `customSentMessage` is true, it means we want to save the `baseMessage`
  // as sent. This is because that means that we sent a message per recipient for
  // tracking, but we actually /just/ want to show the baseMessage as sent
  if (customSentMessage) {
    const rawMime = yield buildMime(baseMessage, {includeBcc: true});
    const box = yield imap.openBox(allMailFolder.name);

    yield box.append(rawMime, {flags: 'SEEN'})

    const {headerMessageId} = baseMessage
    const uids = yield box.search([['HEADER', 'Message-ID', headerMessageId]])
    // There should only be one uid in the array
    yield box.setLabels(uids[0], sentLabel.imapLabelIdentifier());
  }

  // If IMAP succeeds, fetch any new messages in the sent folder which
  // should include the messages we just created there
  // The sync operation will save the changes to the database.
  // TODO add transaction
  const syncOperation = SyncTaskFactory.create('FetchNewMessagesInFolder', {
    account,
    folder: allMailFolder,
  })
  yield syncOperation.run(db, imap, {syncWorker})
}

async function* setThreadingReferences(db, baseMessage) {
  const {Message, Reference} = db
  // TODO When the message was created for sending, we set the
  // `inReplyToLocalMessageId` if it exists, and we set the temporary properties
  // `inReplyTo` and `references` for sending.
  // Since these properties aren't saved to the model, we need to recreate
  // them again because they are necessary for building the correct raw mime
  // message to add to the sent folder
  // We should clean this up
  const replyToMessage = yield Message.findById(
    baseMessage.inReplyToLocalMessageId,
    { include: [{model: Reference, as: 'references', attributes: ['id', 'rfc2822MessageId']}] }
  )
  if (replyToMessage) {
    const {inReplyTo, references} = getReplyHeaders(replyToMessage);
    baseMessage.inReplyTo = inReplyTo;
    baseMessage.references = references;
  }
}

/**
 * Ensures that sent messages show up in the sent folder.
 *
 * Gmail does this automatically. IMAP needs to do this manually.
 *
 * We sometimes request a  `customSentMessage` because we may have
 * individualized a bunch of messages via multi-send, or have link & open
 * tracking data that we don't want to see in our sent folder. Regardless
 * we need to make it look like you only sent 1 message. To do this we,
 * delete all of the messages Gmail automatically created (keyed by the
 * same Meassage-Id header we set), then stuff a copy of the original
 * message in the sent folder.
 */
class EnsureMessageInSentFolderIMAP extends SyncbackIMAPTask {
  description() {
    return `EnsureMessageInSentFolder`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async * _run(db, imap, {syncWorker} = {}) {
    const {Message} = db
    const {messageId, customSentMessage} = this.syncbackRequestObject().props

    const baseMessage = yield Message.findById(messageId, {
      include: [{model: db.Folder}, {model: db.Label}, {model: db.File}],
    });

    if (!baseMessage) {
      throw new APIError(`Couldn't find message ${messageId} to stuff in sent folder`, 500)
    }

    yield setThreadingReferences(db, baseMessage)

    const {provider} = this._account
    const {headerMessageId} = baseMessage

    // Gmail automatically creates sent messages when sending, so we
    // delete each of the ones we sent to each recipient in the
    // `SendMessagePerRecipient` task
    //
    // Each participant gets a message, but all of those messages have the
    // same Message-ID header in them. This allows us to find all of the
    // sent messages and clean them up
    if (customSentMessage && provider === Provider.Gmail) {
      try {
        yield deleteGmailSentMessages({db, imap, provider, headerMessageId})
      } catch (err) {
        // Even if this fails, we need to finish attempting to save the
        // baseMessage to the sent folder
        this._logger.error(err, 'EnsureMessageInSentFolder: Failed to delete Gmail sent messages');
      }
    }

    yield saveSentMessage({db, account: this._account, syncWorker, logger: this._logger, imap, provider, customSentMessage, baseMessage})
    return baseMessage.toJSON()
  }
}

module.exports = EnsureMessageInSentFolderIMAP;
