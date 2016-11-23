const LocalDatabaseConnector = require('../../src/shared/local-database-connector');

/*
 * Mocks out various Model and Instance methods to prevent actually saving data
 * to the sequelize database. Note that with the current implementation, only
 * instances created with Model.build() are mocked out.
 *
 * Currently mocks out the following:
 *   Model
 *     .build()
 *     .findAll()
 *   Instance
 *     .destroy()
 *     .save()
 *
 */
function mockDatabase() {
  return LocalDatabaseConnector.forAccount(-1).then((db) => {
    const data = {};
    for (const modelName of Object.keys(db.sequelize.models)) {
      const model = db.sequelize.models[modelName];
      data[modelName] = {};

      spyOn(model, 'findAll').and.callFake(() => {
        return Promise.resolve(
          Object.keys(data[modelName]).map(key => data[modelName][key])
        );
      });

      const origBuild = model.build;
      spyOn(model, 'build').and.callFake((...args) => {
        const instance = origBuild.apply(model, args);

        spyOn(instance, 'save').and.callFake(() => {
          if (instance.id == null) {
            const sortedIds = Object.keys(data[modelName]).sort();
            const len = sortedIds.length;
            instance.id = len ? +sortedIds[len - 1] + 1 : 0;
          }
          data[modelName][instance.id] = instance;
        });

        spyOn(instance, 'destroy').and.callFake(() => {
          delete data[modelName][instance.id]
        });

        return instance;
      })
    }

    return Promise.resolve(db);
  });
}

module.exports = mockDatabase;
