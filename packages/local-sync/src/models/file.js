const base64 = require('base64-stream');
const {IMAPConnection} = require('isomorphic-core')
const {QuotedPrintableStreamDecoder} = require('../shared/stream-decoders')

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('file', {
    id: { type: Sequelize.STRING(500), primaryKey: true },
    size: Sequelize.INTEGER,
    partId: Sequelize.STRING,
    version: Sequelize.INTEGER,
    charset: Sequelize.STRING,
    encoding: Sequelize.STRING,
    filename: Sequelize.STRING(500),
    messageId: { type: Sequelize.STRING, allowNull: false },
    accountId: { type: Sequelize.STRING, allowNull: false },
    contentType: Sequelize.STRING(500),
    contentId: Sequelize.STRING(500),
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
            fetchOptions: {
              bodies: this.partId ? [this.partId] : [],
              struct: true,
            },
            onFetchComplete() {
              connection.end()
            },
          })
          if (!stream) {
            throw new Error(`Unable to fetch binary data for File ${this.id}`)
          }
          if (/quoted-printable/i.test(this.encoding)) {
            return stream.pipe(new QuotedPrintableStreamDecoder({charset: this.charset}))
          } else if (/base64/i.test(this.encoding)) {
            return stream.pipe(base64.decode());
          }

          // If there is no encoding, or the encoding is something like
          // '7bit', '8bit', or 'binary', just return the raw stream. This
          // stream will be written directly to disk. It's then up to the
          // user's computer to decide how to interpret the bytes we've
          // dumped to disk.
          return stream
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
          content_id: this.contentId,
        };
      },
    },
  });
};
