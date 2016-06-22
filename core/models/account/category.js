module.exports = (sequelize, Sequelize) => {
  const Category = sequelize.define('Category', {
    name: Sequelize.STRING,
    role: Sequelize.STRING,
    syncState: Sequelize.JSONTYPE('syncState'),
  }, {
    classMethods: {
      associate: ({Message}) => {
        Category.hasMany(Message)
      },
    },
  });

  return Category;
};
