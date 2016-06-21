module.exports = (sequelize, Sequelize) => {
  const Category = sequelize.define('Category', {
    name: Sequelize.STRING,
    role: Sequelize.STRING,
    syncState: {
      type: Sequelize.STRING,
      defaultValue: '{}',
      get: function get() {
        return JSON.parse(this.getDataValue('syncState'))
      },
      set: function set(val) {
        this.setDataValue('syncState', JSON.stringify(val));
      },
    },
  }, {
    classMethods: {
      associate: ({Message}) => {
        Category.hasMany(Message)
      },
    },
  });

  return Category;
};
