module.exports = (sequelize, Sequelize) => {
  const MessageUID = sequelize.define('MessageUID', {
    uid: Sequelize.STRING,
    messageHash: Sequelize.STRING,
    flags: {
      type: Sequelize.STRING,
      get: function get() {
        return JSON.parse(this.getDataValue('flags'))
      },
      set: function set(val) {
        this.setDataValue('flags', JSON.stringify(val));
      },
    },
  }, {
    indexes: [
      {
        unique: true,
        fields: ['uid', 'CategoryId', 'messageHash'],
      },
    ],
    classMethods: {
      associate: ({Category}) => {
        MessageUID.belongsTo(Category)
      },
    },
  });

  return MessageUID;
};
