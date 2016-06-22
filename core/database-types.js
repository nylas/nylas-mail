const Sequelize = require('sequelize');

module.exports = {
  JSONType: (fieldName) => ({
    type: Sequelize.STRING,
    defaultValue: '{}',
    get: function get() {
      return JSON.parse(this.getDataValue(fieldName))
    },
    set: function set(val) {
      this.setDataValue(fieldName, JSON.stringify(val));
    },
  }),
}
