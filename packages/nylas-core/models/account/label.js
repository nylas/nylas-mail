module.exports = (sequelize, Sequelize) => {
  return sequelize.define('label', {
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    name: Sequelize.STRING,
    role: Sequelize.STRING,
  }, {
    indexes: [
      {
        unique: true,
        fields: ['role'],
      },
    ],
    classMethods: {
      associate: ({Label, Message, MessageLabel, Thread, ThreadLabel}) => {
        Label.belongsToMany(Message, {through: MessageLabel})
        Label.belongsToMany(Thread, {through: ThreadLabel})
      },
    },
    instanceMethods: {
      toJSON: function toJSON() {
        return {
          id: this.id,
          account_id: this.accountId,
          object: 'label',
          name: this.role,
          display_name: this.name,
        };
      },
    },
  });
};
