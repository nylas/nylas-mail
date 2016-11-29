const detectThread = require('./detect-thread')
const extractFiles = require('./extract-files')
const extractContacts = require('./extract-contacts')
const LocalDatabaseConnector = require('../shared/local-database-connector')

function processNewMessage(message, imapMessage) {
  process.nextTick(() => {
    const {accountId} = message
    const logger = global.Logger.forAccount({id: accountId}).child({message})
    LocalDatabaseConnector.forAccount(accountId).then((db) => {
      detectThread({db, message})
      .then((thread) => {
        message.threadId = thread.id
        return db.Message.create(message)
      })
      .then(() => extractFiles({db, message, imapMessage}))
      .then(() => extractContacts({db, message}))
      .then(() => {
        logger.info({
          message_id: message.id,
          uid: message.folderImapUID,
        }, `MessageProcessor: Created and processed message`)
      })
      .catch((err) => logger.error(err, `MessageProcessor: Failed`))
    })
  })
}

module.exports = {processNewMessage}
