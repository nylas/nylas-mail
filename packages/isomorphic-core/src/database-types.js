const Sequelize = require('sequelize');

module.exports = {
  JSONColumn(fieldName, options = {}) {
    return Object.assign(options, {
      type: Sequelize.TEXT,
      get() {
        const val = this.getDataValue(fieldName);
        if (!val) {
          const {defaultValue} = options
          return defaultValue ? Object.assign({}, defaultValue) : {};
        }
        return JSON.parse(val);
      },
      set(val) {
        this.setDataValue(fieldName, JSON.stringify(val));
      },
      defaultValue: undefined,
    })
  },
  JSONArrayColumn(fieldName, options = {}) {
    return Object.assign(options, {
      type: Sequelize.TEXT,
      get() {
        const val = this.getDataValue(fieldName);
        if (!val) {
          const {defaultValue} = options
          return defaultValue || [];
        }
        const arr = JSON.parse(val)
        if (!Array.isArray(arr)) {
          throw new Error('JSONArrayType should be an array')
        }
        return JSON.parse(val);
      },
      set(val) {
        if (!Array.isArray(val)) {
          throw new Error('JSONArrayType should be an array')
        }
        this.setDataValue(fieldName, JSON.stringify(val));
      },
      defaultValue: undefined,
    })
  },
}
