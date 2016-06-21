const crypto = require('crypto');

module.exports = (sequelize, Sequelize) => {
  const Message = sequelize.define('Message', {
    messageId: Sequelize.STRING,
    body: Sequelize.STRING,
    rawBody: Sequelize.STRING,
    headers: Sequelize.JSONTYPE('headers'),
    rawHeaders: Sequelize.STRING,
    subject: Sequelize.STRING,
    snippet: Sequelize.STRING,
    hash: Sequelize.STRING,
    date: Sequelize.DATE,
    unread: Sequelize.BOOLEAN,
    starred: Sequelize.BOOLEAN,
    processed: Sequelize.INTEGER,
    to: Sequelize.JSONTYPE('to'),
    from: Sequelize.JSONTYPE('from'),
    cc: Sequelize.JSONTYPE('cc'),
    bcc: Sequelize.JSONTYPE('bcc'),
    CategoryUID: { type: Sequelize.STRING, allowNull: true},
  }, {
    indexes: [
      {
        unique: true,
        fields: ['hash'],
      },
    ],
    classMethods: {
      associate: ({Category}) => {
        Message.belongsTo(Category)
      },
      hashForHeaders: (headers) => {
        return crypto.createHash('sha256').update(headers, 'utf8').digest('hex');
      },
    },
  });

  return Message;
};
