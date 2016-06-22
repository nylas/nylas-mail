module.exports = (Sequelize) => ({
  JSONTYPE: (fieldName) => ({
    type: Sequelize.STRING,
    defaultValue: '{}',
    get: function get() {
      return JSON.parse(this.getDataValue('syncState'))
    },
    set: function set(val) {
      this.setDataValue('syncState', JSON.stringify(val));
    },
  }),
})
