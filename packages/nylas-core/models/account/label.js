module.exports = (sequelize, Sequelize) => {
  const Label = sequelize.define('label', {
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    name: Sequelize.STRING,
    role: Sequelize.STRING,
  }, {
    classMethods: {
      associate: ({Message, Thread}) => {
        Label.belongsToMany(Message, {through: 'message_labels'})
        Label.belongsToMany(Thread, {through: 'thread_labels'})
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

  return Label;
};
