module.exports = (sequelize, Sequelize) => {
  const Thread = sequelize.define('Thread', {
    first_name: Sequelize.STRING,
    last_name: Sequelize.STRING,
    bio: Sequelize.TEXT,
  }, {
    classMethods: {
      associate: (models) => {
        // associations can be defined here
      },
    },
  });

  return Thread;
};
