module.exports = (sequelize, Sequelize) => {
  const MessageUID = sequelize.define('MessageUID', {
    uid: Sequelize.STRING,
  }, {
    classMethods: {
      associate: ({Category, Message}) => {
        MessageUID.belongsTo(Category)
        MessageUID.belongsTo(Message)
      },
    },
  });

  return MessageUID;
};
