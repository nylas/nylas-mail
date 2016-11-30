const Sequelize = require('sequelize');

module.exports = {
  buildJSONColumnOptions: (fieldName, {defaultValue = {}} = {}) => ({
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
  buildJSONARRAYColumnOptions: (fieldName) => ({
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
