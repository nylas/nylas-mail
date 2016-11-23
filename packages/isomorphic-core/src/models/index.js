const fs = require('fs');
const path = require('path');

function loadModels(Sequelize, sequelize, modelsPath, {schema} = {}) {
  const db = {};
  const dirname = path.join(__dirname, modelsPath)
  for (const filename of fs.readdirSync(dirname)) {
    if (filename.endsWith('.js')) {
      let model = require(filename)(sequelize, Sequelize) // eslint-disable-line
      if (schema) {
        model = model.schema(schema);
      }
      db[model.name[0].toUpperCase() + model.name.substr(1)] = model;
    }
  }

  Object.keys(db).forEach((modelName) => {
    if ("associate" in db[modelName]) {
      db[modelName].associate(db);
    }
  });

  return db;
}


module.exports = loadModels
