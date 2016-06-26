const crypto = require('crypto');
const IMAPConnection = require('../../imap-connection')
const {JSONType, JSONARRAYType} = require('../../database-types');


module.exports = (sequelize, Sequelize) => {
  const Message = sequelize.define('Message', {
    rawBody: Sequelize.STRING,
    rawHeaders: Sequelize.STRING,
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
    CategoryUID: { type: Sequelize.STRING, allowNull: true},
  }, {
    indexes: [
      {
        unique: true,
        fields: ['hash'],
      },
    ],
    classMethods: {
      associate: ({Category, Thread}) => {
        Message.belongsTo(Category)
        Message.belongsTo(Thread)
      },
      hashForHeaders: (headers) => {
        return crypto.createHash('sha256').update(headers, 'utf8').digest('hex');
      },
    },
    instanceMethods: {
      fetchRaw({account, db}) {
        const settings = Object.assign({}, account.connectionSettings, account.decryptedCredentials())
        return Promise.props({
          category: this.getCategory(),
          connection: IMAPConnection.connect(db, settings),
        })
        .then(({category, connection}) => {
          return connection.openBox(category.name)
          .then((imapBox) => imapBox.fetchMessage(this.CategoryUID))
          .then((message) => {
            if (message) {
              return Promise.resolve(`${message.headers}${message.body}`)
            }
            return Promise.reject(new Error(`Unable to fetch raw message for Message ${this.id}`))
          })
          .finally(() => connection.end())
        })
      },
      toJSON: function toJSON() {
        return {
          id: this.id,
          body: this.body,
          subject: this.subject,
          snippet: this.snippet,
          date: this.date.getTime() / 1000.0,
          unread: this.unread,
          starred: this.starred,
          category_id: this.CategoryId,
        };
      },
    },
  });

  return Message;
};
