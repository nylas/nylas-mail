module.exports = (sequelize, Sequelize) => {
  const File = sequelize.define('File', {
    filename: Sequelize.STRING,
    contentId: Sequelize.STRING,
    contentType: Sequelize.STRING,
    size: Sequelize.INTEGER,
  }, {
    classMethods: {
      associate: ({Message}) => {
        File.belongsTo(Message)
      },
    },
    instanceMethods: {
      toJSON: function toJSON() {
        return {
          id: this.id,
          object: 'file',
          messageId: this.MessageId,
          filename: this.filename,
          contentId: this.contentId,
          contentType: this.contentType,
          size: this.size,
        };
      },
    },
  });

  return File;
};
