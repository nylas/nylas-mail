import moment from 'moment'
import {GmailOAuthHelpers} from 'cloud-core'
import {SendmailClient} from 'isomorphic-core'
import CloudWorker from '../cloud-worker'
// This assumes there can't be any whitespace in the Message-Id value.
// (Couldn't just use .+ because that doesn't match < or >)
// https://regex101.com/r/1C1WCl/1
const messageIdRegexp = /^\s*message-id: ([^\s]+)\s*$/im

// Search the imapBox for messages that are in reply to origMessageId. Messages
// are not considered new replies if their id is present in seenMessageIdSet.
const asyncHasNewReply = ({imapBox, origMessageId, seenMessageIdSet, origDate}) => {
  return new Promise(async (resolve, reject) => {
    try {
      let count = 0;

      // We subtract one day to make sure there aren't any timezone issues.
      const sinceDateString = moment(origDate).subtract(1, 'day').format('MMMM D, YYYY')

      const replyUIDS = await imapBox.search([
        ['HEADER', 'IN-REPLY-TO', origMessageId],
        ['SINCE', sinceDateString],
      ])
      if (replyUIDS.length === 0) {
        resolve(false)
        return;
      }
      let resolved = false;
      // We have to fetch the messages to check their message-id headers. Boo.
      imapBox.fetchEach(replyUIDS, {bodies: 'HEADER'},
        // This callback will get called asynchronously for each message,
        // but we only want to call resolve once.
        ({headers}) => {
          if (resolved) { return; } // We already found a new reply
          const match = headers.toString().match(messageIdRegexp)
          if (match) {
            const replyMessageId = match[1];
            if (!seenMessageIdSet.has(replyMessageId)) {
              if (!resolved) { // Don't call resolve more than once
                resolved = true;
                resolve(true)
              }
              return;
            }
          } else {
            this.logger.error({
              err: new Error("Couldn't find a Message-Id header"),
              inReplyTo: origMessageId,
            })
          }
          count++;
          if (count === replyUIDS.length) {
            // We've gone through every single message, there were no new replies
            resolve(false)
          }
        }
      )
    } catch (error) {
      reject(error)
    }
  })
}

export default class SendRemindersWorker extends CloudWorker {
  pluginId() {
    return 'send-reminders';
  }

  async performAction({metadatum, account, connection}) {
    const {messageIdHeaders, folderImapNames, replyTo, subject} = metadatum.value
    if (!messageIdHeaders || !folderImapNames || !replyTo) {
      throw new Error("Can't send reminder, no metadata value")
    }
    const messageIdSet = new Set(messageIdHeaders)
    for (const folderImapName of folderImapNames) {
      const box = await connection.openBox(folderImapName)
      for (const messageId of messageIdHeaders) {
        // TODO: Eventually, we should make the app send the message date with
        // the metadata. At this time we're trying to get a release out and
        // don't want to wait for yet another build, so for now the createdAt
        // date of the metadatum should be close enough, especially given the 1
        // day buffer within asyncHasNewReply().
        const hasNewReply = await asyncHasNewReply({
          imapBox: box,
          origmessageId: messageId,
          seenMessageIdSet: messageIdSet,
          origDate: metadatum.createdAt,
        })
        if (hasNewReply) {
          this.logger.info("Skipping reminder, thread has already been replied to")
          return Promise.resolve();
        }
      }
    }
    const {accountId, objectId, pluginId} = metadatum
    let sender;
    try {
      sender = new SendmailClient(account, this.logger)
    } catch (error) {
      // The cloud version of the account might not have the xoauth2 token yet
      if (/missing xoauth2 token/i.test(error.message)) {
        await GmailOAuthHelpers.refreshAccessToken(account)
        sender = new SendmailClient(account, this.logger)
      } else {
        throw error
      }
    }
    const message = {
      to: [{name: account.name, email: account.emailAddress}],
      from: [{name: `${account.name} via Nylas Mail`, email: account.emailAddress}],
      subject: subject,
      body: "Nylas Mail Reminder:<br/><br/>This thread has been moved to " +
        "the top of your inbox by Nylas because no one has replied to your " +
        "message<br/><br/>--The Nylas Team",
      inReplyTo: replyTo,
    }
    await sender.send(message)
    const threadMetadata = await this.db.Metadata.find({
      where: {
        accountId: accountId,
        objectId: `t:${objectId}`,
        objectType: 'thread',
        pluginId: pluginId,
      },
    })
    if (threadMetadata) {
      // `threadMetadata.value.shouldNotify = true` doesn't work, so use Object.assign
      threadMetadata.value = Object.assign(threadMetadata.value, {shouldNotify: true})
      return threadMetadata.save()
    }
    // If there are equivalent thread metadata with different ids,
    // the mail client should catch this and syncback the metadata
    // with all the message ids so the cloud can reconcile them.
    return this.db.Metadata.create({
      accountId: accountId,
      objectId: `t:${objectId}`,
      objectType: 'thread',
      pluginId: pluginId,
      version: 0,
      value: {shouldNotify: true},
      expiration: null,
    })
  }
}
