
module.exports = (db) => {
  for (const modelName of Object.keys(db)) {
    const model = db[modelName];

    model.beforeCreate('increment-version-c', (instance) => {
      instance.version = 1;
    });
    model.beforeUpdate('increment-version-u', (instance) => {
      instance.version = instance.version ? instance.version + 1 : 1;
    });
  }
}
