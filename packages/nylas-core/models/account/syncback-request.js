module.exports = (sequelize, Sequelize) => {
  const SyncbackRequest = sequelize.define('SyncbackRequest', {
    type: Sequelize.STRING,
    status: {
      type: Sequelize.ENUM("NEW", "SUCCEEDED", "FAILED"),
      defaultValue: "NEW",
      allowNull: false,
    },
    error: {
      type: Sequelize.STRING,
      get: function get() {
        return JSON.parse(this.getDataValue('error'))
      },
      set: function set(val) {
        this.setDataValue('error', JSON.stringify(val));
      },
    },
    props: {
      type: Sequelize.STRING,
      get: function get() {
        return JSON.parse(this.getDataValue('props'))
      },
      set: function set(val) {
        this.setDataValue('props', JSON.stringify(val));
      },
    },
  });

  return SyncbackRequest;
};
