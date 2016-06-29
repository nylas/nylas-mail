const crypto = require('crypto');
const IMAPConnection = require('../../imap-connection')
const NylasError = require('../../nylas-error')
const {JSONType, JSONARRAYType} = require('../../database-types');


module.exports = (sequelize, Sequelize) => {
  const Message = sequelize.define('message', {
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    messageId: Sequelize.STRING,
    body: Sequelize.STRING,
    headers: JSONType('headers'),
    subject: Sequelize.STRING,
    snippet: Sequelize.STRING,
    hash: Sequelize.STRING,
    date: Sequelize.DATE,
    unread: Sequelize.BOOLEAN,
    starred: Sequelize.BOOLEAN,
    processed: Sequelize.INTEGER,
    to: JSONARRAYType('to'),
    from: JSONARRAYType('from'),
    cc: JSONARRAYType('cc'),
    bcc: JSONARRAYType('bcc'),
    categoryUID: { type: Sequelize.STRING, allowNull: true},
  }, {
    indexes: [
      {
        unique: true,
        fields: ['hash'],
      },
    ],
    classMethods: {
      associate: ({Category, File, Thread}) => {
        Message.belongsTo(Category)
        Message.hasMany(File, {as: 'files'})
        Message.belongsTo(Thread)
      },
      hashForHeaders: (headers) => {
        return crypto.createHash('sha256').update(headers, 'utf8').digest('hex');
      },
    },
    instanceMethods: {
      fetchRaw: function fetchRaw({account, db}) {
        const settings = Object.assign({}, account.connectionSettings, account.decryptedCredentials())
        return Promise.props({
          category: this.getCategory(),
          connection: IMAPConnection.connect(db, settings),
        })
        .then(({category, connection}) => {
          return connection.openBox(category.name)
          .then((imapBox) => imapBox.fetchMessage(this.categoryUID))
          .then((message) => {
            if (message) {
              return Promise.resolve(`${message.headers}${message.body}`)
            }
            return Promise.reject(new NylasError(`Unable to fetch raw message for Message ${this.id}`))
          })
          .finally(() => connection.end())
        })
      },

      toJSON: function toJSON() {
        if (this.category_id && !this.category) {
          throw new Error("Message.toJSON called on a message where category were not eagerly loaded.")
        }

        return {
          id: this.id,
          account_id: this.accountId,
          object: 'message',
          body: this.body,
          subject: this.subject,
          snippet: this.snippet,
          date: this.date.getTime() / 1000.0,
          unread: this.unread,
          starred: this.starred,
          folder: this.category,
        };
      },
    },
  });

  return Message;
};
