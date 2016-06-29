const {JSONType} = require('../../database-types');

module.exports = (sequelize, Sequelize) => {
  const Category = sequelize.define('category', {
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    name: Sequelize.STRING,
    role: Sequelize.STRING,
    type: Sequelize.ENUM('folder', 'label'),
    syncState: JSONType('syncState'),
  }, {
    classMethods: {
      associate: ({Message, Thread, ThreadCategory}) => {
        Category.hasMany(Message)
        Category.belongsToMany(Thread, {through: ThreadCategory})
      },
    },
    instanceMethods: {
      toJSON: function toJSON() {
        return {
          id: this.id,
          account_id: this.accountId,
          object: this.type,
          name: this.role,
          display_name: this.name,
        };
      },
    },
  });

  return Category;
};
