const Sequelize = require('sequelize');
const fs = require('fs');
const path = require('path');
const {loadModels, HookIncrementVersionOnSave, HookTransactionLog} = require('isomorphic-core')
const PubsubConnector = require('./pubsub-connector');

require('./database-extensions'); // Extends Sequelize on require

const STORAGE_DIR = path.join(__dirname, '..', '..', 'storage');
try {
  if (!fs.existsSync(STORAGE_DIR)) {
    fs.mkdirSync(STORAGE_DIR);
  }
} catch (err) {
  global.Logger.error(err, 'Error creating storage directory')
}

class DatabaseConnector {
  constructor() {
    this._cache = {};
  }

  _sequelizePoolForDatabase(dbname) {
    if (process.env.DB_HOSTNAME) {
      return new Sequelize(dbname, process.env.DB_USERNAME, process.env.DB_PASSWORD, {
        host: process.env.DB_HOSTNAME,
        dialect: "mysql",
        charset: 'utf8',
        logging: false,
        pool: {
          min: 1,
          max: 15,
          idle: 5000,
        },
        define: {
          charset: 'utf8',
          collate: 'utf8_general_ci',
        },
      });
    }

    return new Sequelize(dbname, '', '', {
      storage: path.join(STORAGE_DIR, `${dbname}.sqlite`),
      dialect: "sqlite",
      logging: false,
    })
  }

  _sequelizeForShared() {
    const sequelize = this._sequelizePoolForDatabase(process.env.DB_NAME);
    const db = loadModels(Sequelize, sequelize, {
      modelDirs: [path.join(__dirname, 'models')],
    })

    HookTransactionLog(db, sequelize, {
      only: ['metadata'],
      onCreatedTransaction: (transaction) => {
        PubsubConnector.notifyDelta(transaction.accountId, transaction.toJSON());
      },
    });
    HookIncrementVersionOnSave(db, sequelize);

    db.sequelize = sequelize;
    db.Sequelize = Sequelize;

    return sequelize.authenticate().then(() =>
      sequelize.sync()
    ).thenReturn(db);
  }

  forShared() {
    this._cache.shared = this._cache.shared || this._sequelizeForShared();
    return this._cache.shared;
  }
}

module.exports = new DatabaseConnector()
