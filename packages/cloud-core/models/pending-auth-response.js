module.exports = (sequelize, Sequelize) => {
  const PendingAuthResponse = sequelize.define('pendingAuthResponse', {
    response: Sequelize.TEXT('long'),
    pendingAuthKey: Sequelize.STRING,
  }, {
    classMethods: {
      associate: () => {
      },
    },
  });

  return PendingAuthResponse;
};
