module.exports = (sequelize, Sequelize) => {
  const AccountToken = sequelize.define('AccountToken', {
    value: Sequelize.STRING,
  }, {
    classMethods: {
      associate: ({Account}) => {
        AccountToken.belongsTo(Account, {
          onDelete: "CASCADE",
          foreignKey: {
            allowNull: false,
          },
        });
      },
    },
  });

  return AccountToken;
};
