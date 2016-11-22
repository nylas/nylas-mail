const Sequelize = require('sequelize');

module.exports = {
  JSONType: (fieldName, {defaultValue = {}} = {}) => ({
    type: Sequelize.TEXT,
    get: function get() {
      const val = this.getDataValue(fieldName);
      if (!val) {
        return defaultValue ? Object.assign({}, defaultValue) : null;
      }
      return JSON.parse(val);
    },
    set: function set(val) {
      this.setDataValue(fieldName, JSON.stringify(val));
    },
  }),
  JSONARRAYType: (fieldName) => ({
    type: Sequelize.TEXT,
    get: function get() {
      const val = this.getDataValue(fieldName);
      if (!val) {
        return [];
      }
      return JSON.parse(val);
    },
    set: function set(val) {
      this.setDataValue(fieldName, JSON.stringify(val));
    },
  }),
}
