const Sequelize = require('sequelize');
const fs = require('fs');
const path = require('path');
const HookTransactionLog = require('./hook-transaction-log');
const HookAccountCRUD = require('./hook-account-crud');
const HookIncrementVersionOnSave = require('./hook-increment-version-on-save');

require('./database-extensions'); // Extends Sequelize on require

const STORAGE_DIR = path.join(__dirname, '..', '..', 'storage');
if (!fs.existsSync(STORAGE_DIR)) {
  fs.mkdirSync(STORAGE_DIR);
}

class DatabaseConnector {
  constructor() {
    this._pools = {};
  }

  _readModelsInDirectory(sequelize, dirname) {
    const db = {};
    for (const filename of fs.readdirSync(dirname)) {
      if (filename.endsWith('.js')) {
        const model = sequelize.import(path.join(dirname, filename));
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

  _sequelizeForAccount(accountId) {
    if (!accountId) {
      return Promise.reject(new Error(`You need to pass an accountId to init the database!`))
    }
    const sequelize = this._sequelizePoolForDatabase(`a-${accountId}`);
    const modelsPath = path.join(__dirname, 'models/account');
    const db = this._readModelsInDirectory(sequelize, modelsPath)

    HookTransactionLog(db, sequelize);
    HookIncrementVersionOnSave(db, sequelize);

    db.sequelize = sequelize;
    db.Sequelize = Sequelize;
    db.accountId = accountId;

    return sequelize.authenticate().then(() =>
      sequelize.sync()
    ).thenReturn(db);
  }

  forAccount(accountId) {
    this._pools[accountId] = this._pools[accountId] || this._sequelizeForAccount(accountId);
    return this._pools[accountId];
  }

  ensureAccountDatabase(accountId) {
    const dbname = `a-${accountId}`;

    if (process.env.DB_HOSTNAME) {
      const sequelize = this._sequelizePoolForDatabase(null);
      return sequelize.authenticate().then(() =>
        sequelize.query(`CREATE DATABASE IF NOT EXISTS \`${dbname}\``)
      );
    }
    return Promise.resolve()
  }

  destroyAccountDatabase(accountId) {
    const dbname = `a-${accountId}`;
    if (process.env.DB_HOSTNAME) {
      const sequelize = this._sequelizePoolForDatabase(null);
      return sequelize.authenticate().then(() =>
        sequelize.query(`CREATE DATABASE \`${dbname}\``)
      );
    }
    fs.removeFileSync(path.join(STORAGE_DIR, `${dbname}.sqlite`));
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
    this._pools.shared = this._pools.shared || this._sequelizeForShared();
    return this._pools.shared;
  }
}

module.exports = new DatabaseConnector()
