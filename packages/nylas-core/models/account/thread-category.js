module.exports = (sequelize, Sequelize) => {
  const ThreadCategory = sequelize.define('ThreadCategory', {
    role: Sequelize.STRING,
  });

  return ThreadCategory;
};
