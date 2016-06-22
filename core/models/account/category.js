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
  });

  return Category;
};
