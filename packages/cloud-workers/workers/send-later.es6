import fs from 'fs';
import AWS from 'aws-sdk';
import path from 'path';
import tmp from 'tmp';
import {Promise} from 'bluebird';
import {DatabaseConnector} from 'cloud-core'
import ExpiredDataWorker from './expired-data-worker'
import {SendmailClient, MessageFactory, SendUtils} from '../../isomorphic-core'
import {asyncGetImapConnection} from './utils'

Promise.promisifyAll(fs);

const NODE_ENV = process.env.NODE_ENV || 'production'
const BUCKET_NAME = process.env.BUCKET_NAME
const AWS_ACCESS_KEY_ID = process.env.BUCKET_AWS_ACCESS_KEY_ID
const AWS_SECRET_ACCESS_KEY = process.env.BUCKET_AWS_SECRET_ACCESS_KEY

if (NODE_ENV !== 'development' &&
  (!BUCKET_NAME || !AWS_ACCESS_KEY_ID || !AWS_SECRET_ACCESS_KEY)) {
  throw new Error("You need to define S3 access credentials.")
}

AWS.config.update({
  accessKeyId: AWS_ACCESS_KEY_ID,
  secretAccessKey: AWS_SECRET_ACCESS_KEY })

const s3 = new AWS.S3({apiVersion: '2006-03-01'});


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

  async fetchLocalAttachment(accountId, objectId) {
    const uploadId = `${accountId}-${objectId}`;
    const filepath = path.join("/tmp", "uploads", uploadId);
    return fs.readFileAsync(filepath)
  }

  async deleteLocalAttachment(accountId, objectId) {
    const uploadId = `${accountId}-${objectId}`;
    const filepath = path.join("/tmp", "uploads", uploadId);
    await fs.unlinkAsync(filepath);
  }

  async fetchS3Attachment(accountId, objectId) {
    const uploadId = `${accountId}-${objectId}`;

    return new Promise((resolve, reject) => {
      s3.getObject({
        Bucket: BUCKET_NAME,
        Key: uploadId,
      }, (err, data) => {
        if (err) {
          reject(err);
        }

        const body = data.Body;
        resolve(body);
      })
    });
  }

  async deleteS3Attachment(accountId, objectId) {
    const uploadId = `${accountId}-${objectId}`;

    return new Promise((resolve, reject) => {
      s3.deleteObject({
        Bucket: BUCKET_NAME,
        Key: uploadId,
      }, (err, data) => {
        if (err) {
          reject(err);
        }

        resolve(data);
      })
    });
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
        logger.error({err: error, recipient: recipient.email}, 'SendMessagePerRecipient: Failed to send to recipient');
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

  async hydrateAttachments(baseMessage, accountId) {
    // We get a basic JSON message from the metadata database. We need to set
    // some fields (e.g: the `attachments` field) for it to be ready to send.
    // We call this "hydrating" it.
    const attachments = [];
    for (const upload of baseMessage.uploads) {
      const attach = {};
      attach.filename = upload.filename;

      let attachmentContents;
      if (NODE_ENV === 'development') {
        attachmentContents = await this.fetchLocalAttachment(accountId, upload.id);
      } else {
        attachmentContents = await this.fetchS3Attachment(accountId, upload.id);
      }

      // This is very cumbersome. There is a bug in the npm module we use to
      // generate MIME messages – we can't pass it the buffer we get form S3
      // because it will fail in mysterious ways 5 functions down the stack.
      // To make things more complicated, the original author of the module
      // took it offline. After wrestling with this for a couple day, I decided
      // to simply write the file to a temporary directory before attaching it.
      // It's not pretty but it does the job.
      const tmpFile = Promise.promisify(tmp.file, {multiArgs: true});
      const writeFile = Promise.promisify(fs.writeFile);

      const [filePath, fd, cleanupCallback] = await tmpFile();
      await writeFile(filePath, attachmentContents);
      attach.targetPath = filePath;
      attach.cleanupCallback = cleanupCallback;

      if (upload.inline) {
        attach.inline = upload.inline;
      }

      attachments.push(attach);
    }

    baseMessage.uploads = attachments;
    return baseMessage;
  }

  async cleanupAttachments(logger, baseMessage, accountId) {
    // Remove all attachments after sending a message.
    for (const upload of baseMessage.uploads) {
      if (NODE_ENV === 'development') {
        await this.deleteLocalAttachment(accountId, upload.id);
      } else {
        await this.deleteS3Attachment(accountId, upload.id);
      }

      if (upload.cleanupCallback) {
        await upload.cleanupCallback();
      }
    }
  }

  async performAction(metadatum) {
    const db = await DatabaseConnector.forShared();

    if (Object.keys(metadatum.value || {}).length === 0) {
      throw new Error("Can't send later, no metadata value")
    }

    const account = await db.Account.find({where: {id: metadatum.accountId}})

    // asyncGetImapConnection refreshes the oauth token and returns us a fresh
    // connection. This way, we don't have to worry about the access token being
    // expired when trying to send messages.
    const conn = await asyncGetImapConnection(db, metadatum.accountId, this.logger);
    const logger = global.Logger.forAccount(account);
    const sender = new SendmailClient(account, logger);
    const usesOpenTracking = metadatum.value.usesOpenTracking || false;
    const usesLinkTracking = metadatum.value.usesLinkTracking || false;
    const baseMessage = await this.hydrateAttachments(metadatum.value, account.id);

    await this.sendPerRecipient({
      db,
      account,
      baseMessage,
      usesOpenTracking,
      usesLinkTracking,
      logger,
    });

    // Sleep to avoid potential race conditions.
    const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms))

    logger.info("Sleeping to avoid Gmail message creation race condition.");
    await sleep(45000);
    // Now, remove all multisend messages from the user's mailbox. We wrap this
    // block in a pokemon exception handler because we don't want to send messages
    // again if it fails.
    try {
      await this.cleanupSentMessages(conn, sender, logger, baseMessage);
      await this.cleanupAttachments(logger, baseMessage, account.id);
    } catch (err) {
      this.logger.error(`Error while trying to process metadatum ${metadatum.id}`, err);
    }
  }
}
