const base64 = require('base64-stream');
const {IMAPConnection} = require('isomorphic-core')

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('file', {
    id: { type: Sequelize.STRING(500), primaryKey: true },
    size: Sequelize.INTEGER,
    partId: Sequelize.STRING,
    version: Sequelize.INTEGER,
    encoding: Sequelize.INTEGER,
    filename: Sequelize.STRING(500),
    messageId: { type: Sequelize.STRING, allowNull: false },
    accountId: { type: Sequelize.STRING, allowNull: false },
    contentType: Sequelize.STRING(500),
  }, {
    indexes: [
      {fields: ['messageId']},
    ],
    classMethods: {
      associate: ({File, Message}) => {
        File.belongsTo(Message)
      },
    },
    instanceMethods: {
      async fetch({account, db, logger}) {
        const settings = Object.assign({}, account.connectionSettings, account.decryptedCredentials())
        const message = await this.getMessage()
        const connection = await IMAPConnection.connect({db, settings, logger})
        try {
          const folder = await message.getFolder()
          const imapBox = await connection.openBox(folder.name)
          const stream = await imapBox.fetchMessageStream(message.folderImapUID, {
            bodies: this.partId ? [this.partId] : [],
            struct: true,
          })
          if (!stream) {
            throw new Error(`Unable to fetch binary data for File ${this.id}`)
          }
          return stream.pipe(base64.decode());
        } catch (err) {
          connection.end();
          throw err
        }
      },

      toJSON() {
        return {
          id: this.id,
          size: this.size,
          object: 'file',
          part_id: this.partId,
          encoding: this.encoding,
          filename: this.filename,
          message_id: this.messageId,
          account_id: this.accountId,
          content_type: this.contentType,
        };
      },
    },
  });
};
