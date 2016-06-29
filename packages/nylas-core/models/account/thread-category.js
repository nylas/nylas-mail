module.exports = (sequelize, Sequelize) => {
  const ThreadCategory = sequelize.define('threadCategory', {
    role: Sequelize.STRING,
  });

  return ThreadCategory;
};
