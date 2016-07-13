const IMAPConnection = require('../../imap-connection')

module.exports = (sequelize, Sequelize) => {
  const File = sequelize.define('file', {
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    filename: Sequelize.STRING(500),
    partId: Sequelize.STRING,
    contentType: Sequelize.STRING(500),
    size: Sequelize.INTEGER,
  }, {
    charset: 'utf8',
    classMethods: {
      associate: ({Message}) => {
        File.belongsTo(Message)
      },
    },
    instanceMethods: {
      fetch: function fetch({account, db, logger}) {
        const settings = Object.assign({}, account.connectionSettings, account.decryptedCredentials())
        return Promise.props({
          message: this.getMessage(),
          connection: IMAPConnection.connect({db, settings, logger}),
        })
        .then(({message, connection}) => {
          return message.getFolder()
          .then((folder) => connection.openBox(folder.name))
          .then((imapBox) => imapBox.fetchMessageStream(message.folderImapUID, {
            bodies: [this.partId],
            struct: true,
          }))
          .then((stream) => {
            if (stream) {
              return Promise.resolve(stream)
            }
            return Promise.reject(new Error(`Unable to fetch binary data for File ${this.id}`))
          })
          .finally(() => connection.end())
        })
      },
      toJSON: function toJSON() {
        return {
          id: this.id,
          object: 'file',
          account_id: this.accountId,
          message_id: this.messageId,
          filename: this.filename,
          part_id: this.partId,
          content_type: this.contentType,
          size: this.size,
        };
      },
    },
  });

  return File;
};
