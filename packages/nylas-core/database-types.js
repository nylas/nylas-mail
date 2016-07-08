const Sequelize = require('sequelize');

module.exports = {
  JSONType: (fieldName, {defaultValue = {}} = {}) => ({
    type: Sequelize.TEXT,
    get: function get() {
      const val = this.getDataValue(fieldName);
      if (!val) { return defaultValue }
      return JSON.parse(val);
    },
    set: function set(val) {
      this.setDataValue(fieldName, JSON.stringify(val));
    },
  }),
  JSONARRAYType: (fieldName, {defaultValue = []} = {}) => ({
    type: Sequelize.TEXT,
    get: function get() {
      const val = this.getDataValue(fieldName);
      if (!val) { return defaultValue }
      return JSON.parse(val);
    },
    set: function set(val) {
      this.setDataValue(fieldName, JSON.stringify(val));
    },
  }),
}
