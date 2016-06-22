const Sequelize = require('sequelize');
const fs = require('fs');
const path = require('path');
const TransactionLog = require('./transaction-log')
const DeltaStreamQueue = require('./delta-stream-queue.js')

require('./database-extensions'); // Extends Sequelize on require

const STORAGE_DIR = path.join(__base, 'storage');
if (!fs.existsSync(STORAGE_DIR)) {
  fs.mkdirSync(STORAGE_DIR);
}

class DatabaseConnectionFactory {
  constructor() {
    this._pools = {};
  }

  setup() {
    DeltaStreamQueue.setup()
  }

  _readModelsInDirectory(sequelize, dirname) {
    const db = {};
    for (const filename of fs.readdirSync(dirname)) {
      if (filename.endsWith('.js')) {
        const model = sequelize.import(path.join(dirname, filename));
        db[model.name] = model;
      }
    }
    Object.keys(db).forEach((modelName) => {
      if ("associate" in db[modelName]) {
        db[modelName].associate(db);
      }
    });

    return db;
  }

  _sequelizeForAccount(accountId) {
    if (!accountId) {
      throw new Error(`You need to pass an accountId to init the database!`)
    }
    const sequelize = new Sequelize(accountId, '', '', {
      storage: path.join(STORAGE_DIR, `a-${accountId}.sqlite`),
      dialect: "sqlite",
      logging: false,
    });

    const modelsPath = path.join(__dirname, 'models/account');
    const db = this._readModelsInDirectory(sequelize, modelsPath)

    db.sequelize = sequelize;
    db.Sequelize = Sequelize;
    db.accountId = accountId;

    const transactionLog = new TransactionLog(db);
    transactionLog.setupSQLHooks(sequelize)

    return sequelize.authenticate().then(() =>
      sequelize.sync()
    ).thenReturn(db);
  }

  forAccount(accountId) {
    this._pools[accountId] = this._pools[accountId] || this._sequelizeForAccount(accountId);
    return this._pools[accountId];
  }

  _sequelizeForShared() {
    const sequelize = new Sequelize('shared', '', '', {
      storage: path.join(STORAGE_DIR, 'shared.sqlite'),
      dialect: "sqlite",
      logging: false,
    });

    const modelsPath = path.join(__dirname, 'models/shared');
    const db = this._readModelsInDirectory(sequelize, modelsPath)

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

module.exports = new DatabaseConnectionFactory()
