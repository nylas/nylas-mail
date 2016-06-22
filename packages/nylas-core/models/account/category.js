const {JSONType} = require('../../database-types');

module.exports = (sequelize, Sequelize) => {
  const Category = sequelize.define('Category', {
    name: Sequelize.STRING,
    role: Sequelize.STRING,
    syncState: JSONType('syncState'),
  }, {
    classMethods: {
      associate: ({Message}) => {
        Category.hasMany(Message)
      },
    },
    instanceMethods: {
      toJSON: function toJSON() {
        return {
          id: this.id,
          name: this.role,
          display_name: this.name,
        };
      },
    },
  });

  return Category;
};
