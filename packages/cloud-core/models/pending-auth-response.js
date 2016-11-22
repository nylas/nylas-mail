module.exports = (sequelize, Sequelize) => {
  const PendingAuthResponse = sequelize.define('pendingAuthResponse', {
    response: Sequelize.STRING,
    pendingAuthKey: Sequelize.STRING,
  }, {
    classMethods: {
      associate: () => {
      },
    },
  });

  return PendingAuthResponse;
};
