const crypto = require('crypto');
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
