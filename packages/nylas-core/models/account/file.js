module.exports = (sequelize, Sequelize) => {
  const File = sequelize.define('file', {
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
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
          account_id: this.accountId,
          message_id: this.messageId,
          filename: this.filename,
          content_id: this.contentId,
          content_type: this.contentType,
          size: this.size,
        };
      },
    },
  });

  return File;
};
