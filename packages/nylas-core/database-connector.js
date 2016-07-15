const Sequelize = require('sequelize');
const fs = require('fs');
const path = require('path');
const HookTransactionLog = require('./hook-transaction-log');
const HookAccountCRUD = require('./hook-account-crud');
const HookIncrementVersionOnSave = require('./hook-increment-version-on-save');
const PromiseUtils = require('./promise-utils');

require('./database-extensions'); // Extends Sequelize on require

const STORAGE_DIR = path.join(__dirname, '..', '..', 'storage');
if (!fs.existsSync(STORAGE_DIR)) {
  fs.mkdirSync(STORAGE_DIR);
}

class DatabaseConnector {
  constructor() {
    this._cache = {};
  }

  _readModelsInDirectory(sequelize, dirname, {schema} = {}) {
    const db = {};
    for (const filename of fs.readdirSync(dirname)) {
      if (filename.endsWith('.js')) {
        let model = sequelize.import(path.join(dirname, filename));
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

  _sequelizePoolForDatabase(dbname) {
    if (process.env.DB_HOSTNAME) {
      return new Sequelize(dbname, process.env.DB_USERNAME, process.env.DB_PASSWORD, {
        host: process.env.DB_HOSTNAME,
        dialect: "mysql",
        charset: 'utf8',
        logging: false,
        pool: {
          min: 1,
          max: 30,
          idle: 10000,
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

  forAccount(accountId) {
    if (!accountId) {
      return Promise.reject(new Error(`You need to pass an accountId to init the database!`))
    }

    if (this._cache[accountId]) {
      return this._cache[accountId];
    }

    let newSequelize = null;

    if (process.env.DB_HOSTNAME) {
      if (!this._accountsRootSequelize) {
        this._accountsRootSequelize = this._sequelizePoolForDatabase(`account_data`);
      }

      // Create a new sequelize instance, but tie it to the same connection pool
      // as the other account instances.
      newSequelize = this._sequelizePoolForDatabase(`account_data`);
      newSequelize.dialect = this._accountsRootSequelize.dialect;
      newSequelize.config = this._accountsRootSequelize.config;
      newSequelize.connectionManager.close()
      newSequelize.connectionManager = this._accountsRootSequelize.connectionManager;
    } else {
      newSequelize = this._sequelizePoolForDatabase(`a-${accountId}`);
    }

    const modelsPath = path.join(__dirname, 'models/account');
    const db = this._readModelsInDirectory(newSequelize, modelsPath, {schema: `a${accountId}`})

    HookTransactionLog(db, newSequelize);
    HookIncrementVersionOnSave(db, newSequelize);

    db.sequelize = newSequelize;
    db.Sequelize = Sequelize;
    db.accountId = accountId;

    this._cache[accountId] = newSequelize.authenticate().thenReturn(db);

    return this._cache[accountId];
  }

  ensureAccountDatabase(accountId) {
    return this.forAccount(accountId).then((db) => {
      // this is a bit of a hack, because sequelize.sync() doesn't work with
      // schemas. It's necessary to sync models individually and in the right order.
      const models = ['Contact', 'Folder', 'Label', 'Transaction', 'Thread', 'ThreadLabel', 'ThreadFolder', 'Message', 'MessageLabel', 'File', 'SyncbackRequest'];
      return PromiseUtils.each(models, (n) =>
        db[n].sync()
      )
    });
  }

  destroyAccountDatabase(accountId) {
    const dbname = `a-${accountId}`;
    if (process.env.DB_HOSTNAME) {
      // todo
    } else {
      fs.removeFileSync(path.join(STORAGE_DIR, `${dbname}.sqlite`));
    }
    return Promise.resolve()
  }

  _sequelizeForShared() {
    const sequelize = this._sequelizePoolForDatabase(`shared`);
    const modelsPath = path.join(__dirname, 'models/shared');
    const db = this._readModelsInDirectory(sequelize, modelsPath)

    HookAccountCRUD(db, sequelize);

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
