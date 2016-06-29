const Sequelize = require('sequelize');

module.exports = {
  typeJSON: function typeJSON(key) {
    return {
      type: Sequelize.STRING,
      get: function get() {
        const val = this.getDataValue(key);
        if (typeof val === 'string') {
          try {
            return JSON.parse(val)
          } catch (e) {
            return val
          }
        }
        return val
      },
      set: function set(val) {
        let valToSet = val
        if (typeof val !== 'string') {
          try {
            valToSet = JSON.stringify(val)
          } catch (e) {
            valToSet = val;
          }
        }
        return this.setDataValue(key, valToSet)
      },
    }
  },
}
