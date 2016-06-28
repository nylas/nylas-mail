module.exports = (sequelize, Sequelize) => {
  const File = sequelize.define('File', {
    partId: Sequelize.STRING,
    type: Sequelize.STRING,
    subtype: Sequelize.STRING,
    dispositionType: Sequelize.STRING,
    size: Sequelize.INTEGER,
    name: Sequelize.STRING,
  }, {
    classMethods: {
      associate: ({Message}) => {
        File.belongsTo(Message)
      },
    },
  });

  return File;
};
