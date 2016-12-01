const _ = require('underscore');

module.exports = (db) => {
  for (const modelName of Object.keys(db)) {
    const model = db[modelName];

    const allIgnoredFields = (changedFields) => {
      return _.isEqual(changedFields, ['syncState']);
    }

    model.beforeCreate('increment-version-c', (instance) => {
      instance.version = 1;
    });
    model.beforeUpdate('increment-version-u', (instance) => {
      if (!allIgnoredFields(Object.keys(instance._changed))) {
        instance.version = instance.version ? instance.version + 1 : 1;
      }
    });
  }
}
