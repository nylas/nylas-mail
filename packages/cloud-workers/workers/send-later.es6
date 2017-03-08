import {DatabaseConnector} from 'cloud-core'
import ExpiredDataWorker from './expired-data-worker'
import {SendmailClient, MessageFactory, SendUtils} from '../../isomorphic-core'
import {asyncGetImapConnection} from './utils'


export default class SendLaterWorker extends ExpiredDataWorker {
  pluginId() {
    return 'send-later';
  }

  _identifyFolderRole(folderTable, role, prefix) {
    // identify the sent folder in the list of IMAP boxes node-imap returns.
    // this is a little complex because node-imap tries to
    // abstract IMAP folders – regular IMAP doesn't support recursive folders,
    // so we need to rebuild the actual name of the folder to be able to save
    // files in it. Hence, the recursive function passing a prefix around.
    for (const folderName of Object.keys(folderTable)) {
      const folder = folderTable[folderName];
      if (folder.attribs.indexOf(role) !== -1) {
        return prefix + folderName;
      }

      let recursiveResult = null;
      if (folder.children) {
        if (prefix !== '') {
          recursiveResult = this._identifyFolderRole(folder.children, role,
                                                    prefix + folderName + folder.delimiter);
        } else {
          recursiveResult = this._identifyFolderRole(folder.children, role,
                                                    folderName + folder.delimiter);
        }

        if (recursiveResult) {
          return recursiveResult;
        }
      }
    }

    return null;
  }

  identifySentFolder(folderTable) {
    return this._identifyFolderRole(folderTable, '\\Sent', '');
  }

  identifyTrashFolder(folderTable) {
    return this._identifyFolderRole(folderTable, '\\Trash', '');
  }

  async sendPerRecipient({db, account, baseMessage, usesOpenTracking, usesLinkTracking, logger = console} = {}) {
    const recipients = [].concat(baseMessage.to, baseMessage.cc, baseMessage.bcc);
    const failedRecipients = []

    for (const recipient of recipients) {
      const customBody = MessageFactory.buildTrackingBodyForRecipient({
        recipient,
        baseMessage,
        usesOpenTracking,
        usesLinkTracking,
      })

      const individualizedMessage = SendUtils.deepClone(baseMessage);
      individualizedMessage.body = customBody;
      // TODO we set these temporary properties which aren't stored in the
      // database model because SendmailClient requires them to send the message
      // with the correct headers.
      // This should be cleaned up
      individualizedMessage.references = baseMessage.references;
      individualizedMessage.inReplyTo = baseMessage.inReplyTo;

      try {
        const sender = new SendmailClient(account, logger);
        await sender.sendCustom(individualizedMessage, {to: [recipient]})
      } catch (error) {
        logger.error(error, {recipient: recipient.email}, 'SendMessagePerRecipient: Failed to send to recipient');
        failedRecipients.push(recipient.email)
      }
    }
    if (failedRecipients.length === recipients.length) {
      throw new Error('SendMessagePerRecipient: Sending failed for all recipients', 500);
    }
    return {failedRecipients}
  }

  async cleanupSentMessages(conn, sender, logger, message) {
    await conn.connect();

    let sentFolder;
    let trashFolder;

    if (message.sentFolderName) {
      logger.info("Using supplied sent folder", message.sentFolderName);
      sentFolder = message.sentFolderName;
    } else {
      const boxes = await conn.getBoxes();
      sentFolder = this.identifySentFolder(boxes);
    }

    if (message.trashFolderName) {
      logger.info("Using supplied trash folder", message.trashFolderName);
      trashFolder = message.trashFolderName;
    } else {
      const boxes = await conn.getBoxes();
      trashFolder = this.identifyTrashFolder(boxes);
    }

    const box = await conn.openBox(sentFolder);

    // Remove all existing messages.
    const uids = await box.search([['HEADER', 'Message-ID', message.message_id_header]])
    logger.warn("Found uids", uids);
    for (const uid of uids) {
      logger.info("Moving to box", trashFolder);
      await box.addFlags(uid, 'DELETED')
      await box.moveFromBox(uid, trashFolder);
    }

    // Add a single message without tracking information.
    const rawMime = await sender.buildMime(message);
    await box.append(rawMime, {flags: 'SEEN'});

    await box.closeBox();

    // Now, go the trash folder and remove all messages marked as deleted.
    const trashBox = await conn.openBox(trashFolder);
    await trashBox.closeBox({expunge: true});
  }

  async performAction(metadatum) {
    const db = await DatabaseConnector.forShared();
    const account = await db.Account.find({where: {id: metadatum.accountId}})

    // asyncGetImapConnection refreshes the oauth token and returns us a fresh
    // connection. This way, we don't have to worry about the access token being
    // expired when trying to send messages.
    const conn = await asyncGetImapConnection(db, metadatum.accountId, this.logger);
    const logger = global.Logger.forAccount(account);
    const sender = new SendmailClient(account, logger);
    const usesOpenTracking = metadatum.value.usesOpenTracking || false;
    const usesLinkTracking = metadatum.value.usesLinkTracking || false;
    await this.sendPerRecipient({
      db,
      account,
      baseMessage: metadatum.value,
      usesOpenTracking,
      usesLinkTracking,
      logger});

    // Sleep to avoid potential race conditions.
    const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms))

    logger.info("Sleeping to avoid Gmail message creation race condition.");
    await sleep(30000);
    // Now, remove all multisend messages from the user's mailbox. We wrap this
    // block in a pokemon exception handler because we don't want to send messages
    // again if it fails.
    try {
      await this.cleanupSentMessages(conn, sender, logger, metadatum.value);
    } catch (err) {
      this.logger.error(`Error while trying to process metadatum ${metadatum.id}`, err);
    }
  }
}
