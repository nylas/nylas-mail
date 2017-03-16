module.exports = (sequelize, Sequelize) => {
  const AccountToken = sequelize.define('accountToken', {
    value: {
      type: Sequelize.UUID,
      defaultValue: Sequelize.UUIDV4,
    },
  }, {
    indexes: [
      { fields: ['value'] },
    ],
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
