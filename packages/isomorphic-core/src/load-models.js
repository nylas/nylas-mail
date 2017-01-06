const fs = require('fs');
const path = require('path');


function loadModels(Sequelize, sequelize, {loadShared = true, modelDirs = [], schema} = {}) {
  if (loadShared) {
    modelDirs.unshift(path.join(__dirname, 'models'))
  }

  const db = {};

  for (const modelsDir of modelDirs) {
    for (const filename of fs.readdirSync(modelsDir)) {
      if (filename.endsWith('.js') || filename.endsWith('.es6')) {
        let model = sequelize.import(path.join(modelsDir, filename));
        if (schema) {
          model = model.schema(schema);
        }
        db[model.name[0].toUpperCase() + model.name.substr(1)] = model;
      }
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
