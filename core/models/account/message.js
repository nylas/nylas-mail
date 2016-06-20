const crypto = require('crypto');

module.exports = (sequelize, Sequelize) => {
  const Message = sequelize.define('Message', {
    subject: Sequelize.STRING,
    snippet: Sequelize.STRING,
    body: Sequelize.STRING,
    hash: Sequelize.STRING,
    headers: Sequelize.STRING,
    date: Sequelize.DATE,
    unread: Sequelize.BOOLEAN,
    starred: Sequelize.BOOLEAN,
  }, {
    classMethods: {
      associate: ({MessageUID}) => {
        // is this really a good idea?
        // Message.hasMany(Contact, {as: 'from'})
        Message.hasMany(MessageUID, {as: 'uids'})
      },
      hashForHeaders: (headers) => {
        return crypto.createHash('sha256').update(headers, 'utf8').digest('hex');
      },
    },
  });

  return Message;
};
