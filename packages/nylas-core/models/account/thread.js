module.exports = (sequelize, Sequelize) => {
  const Thread = sequelize.define('Thread', {
    threadId: Sequelize.STRING,
    subject: Sequelize.STRING,
    cleanedSubject: Sequelize.STRING,
    unreadCount: Sequelize.INTEGER,
    starredCount: Sequelize.INTEGER,
    firstMessageTimestamp: Sequelize.DATE,
    lastMessageTimestamp: Sequelize.DATE,
    lastMessageReceivedTimestamp: Sequelize.DATE,
  }, {
    classMethods: {
      associate: ({Message}) => {
        Thread.hasMany(Message, {as: 'messages'})
      },
    },
  });

  return Thread;
};
