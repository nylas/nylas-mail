const fs = require('fs');
const path = require('path');

function loadModels(Sequelize, sequelize, {modelsDir = __dirname, modelsSubPath = '', schema} = {}) {
  const db = {};
  const fullModelsDir = path.join(modelsDir, modelsSubPath)
  for (const filename of fs.readdirSync(fullModelsDir)) {
    if (filename.endsWith('.js')) {
      let model = sequelize.import(path.join(fullModelsDir, filename));
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
