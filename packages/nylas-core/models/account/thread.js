module.exports = (sequelize, Sequelize) => {
  const Thread = sequelize.define('Thread', {
    threadId: Sequelize.STRING,
    subject: Sequelize.STRING,
    cleanedSubject: Sequelize.STRING,
  }, {
    classMethods: {
      associate: ({Message}) => {
        Thread.hasMany(Message, {as: 'messages'})
      },
    },
  });

  return Thread;
};
