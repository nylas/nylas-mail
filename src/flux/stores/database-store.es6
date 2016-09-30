/* eslint global-require: 0 */
import async from 'async';
import path from 'path';
import fs from 'fs';
import sqlite3 from 'sqlite3';
import PromiseQueue from 'promise-queue';
import NylasStore from '../../global/nylas-store';
import {remote, ipcRenderer} from 'electron';

import Utils from '../models/utils';
import Query from '../models/query';
import DatabaseChangeRecord from './database-change-record';
import DatabaseTransaction from './database-transaction';
import DatabaseSetupQueryBuilder from './database-setup-query-builder';

const DatabaseVersion = 23;
const DatabasePhase = {
  Setup: 'setup',
  Ready: 'ready',
  Close: 'close',
}

const DEBUG_TO_LOG = false;
const DEBUG_QUERY_PLANS = NylasEnv.inDevMode();

const COMMIT = 'COMMIT';

let JSONBlob = null;

/*
Public: N1 is built on top of a custom database layer modeled after
ActiveRecord. For many parts of the application, the database is the source
of truth. Data is retrieved from the API, written to the database, and changes
to the database trigger Stores and components to refresh their contents.

The DatabaseStore is available in every application window and allows you to
make queries against the local cache. Every change to the local cache is
broadcast as a change event, and listening to the DatabaseStore keeps the
rest of the application in sync.

#// Listening for Changes

To listen for changes to the local cache, subscribe to the DatabaseStore and
inspect the changes that are sent to your listener method.

```coffeescript
this.unsubscribe = DatabaseStore.listen(this._onDataChanged, this.)

...

_onDataChanged: (change) ->
  return unless change.objectClass is Message
  return unless this._myMessageID in _.map change.objects, (m) -> m.id

  // Refresh Data

```

The local cache changes very frequently, and your stores and components should
carefully choose when to refresh their data. The \`change\` object passed to your
event handler allows you to decide whether to refresh your data and exposes
the following keys:

\`objectClass\`: The {Model} class that has been changed. If multiple types of models
were saved to the database, you will receive multiple change events.

\`objects\`: An {Array} of {Model} instances that were either created, updated or
deleted from the local cache. If your component or store presents a single object
or a small collection of objects, you should look to see if any of the objects
are in your displayed set before refreshing.

Section: Database
*/
class DatabaseStore extends NylasStore {

  static ChangeRecord = DatabaseChangeRecord;

  constructor() {
    super();

    this._triggerPromise = null;
    this._inflightTransactions = 0;
    this._open = false;
    this._waiting = [];

    this.setupEmitter();
    this._emitter.setMaxListeners(100);

    if (NylasEnv.inSpecMode()) {
      this._databasePath = path.join(NylasEnv.getConfigDirPath(), 'edgehill.test.db');
    } else {
      this._databasePath = path.join(NylasEnv.getConfigDirPath(), 'edgehill.db');
    }

    this._databaseMutationHooks = [];

    // Listen to events from the application telling us when the database is ready,
    // should be closed so it can be deleted, etc.
    ipcRenderer.on('database-phase-change', () => this._onPhaseChange());
    setTimeout(() => this._onPhaseChange(), 0);
  }

  _onPhaseChange() {
    if (NylasEnv.inSpecMode()) {
      return;
    }

    const app = remote.getGlobal('application')
    const phase = app.databasePhase()

    if (phase === DatabasePhase.Setup && NylasEnv.isWorkWindow()) {
      this._openDatabase(() => {
        this._checkDatabaseVersion({allowNotSet: true}, () => {
          this._runDatabaseSetup(() => {
            app.setDatabasePhase(DatabasePhase.Ready);
            setTimeout(() => this._runDatabaseAnalyze(), 60 * 1000);
          });
        });
      });
    } else if (phase === DatabasePhase.Ready) {
      this._openDatabase(() => {
        this._checkDatabaseVersion({}, () => {
          this._open = true;
          for (const w of this._waiting) {
            w();
          }
          this._waiting = [];
        });
      });
    } else if (phase === DatabasePhase.Close) {
      this._open = false;
      if (this._db) {
        this._db.close();
        this._db = null;
      }
    }
  }

  // When 3rd party components register new models, we need to refresh the
  // database schema to prepare those tables. This method may be called
  // extremely frequently as new models are added when packages load.
  refreshDatabaseSchema() {
    if (!NylasEnv.isWorkWindow()) {
      return;
    }
    const app = remote.getGlobal('application');
    const phase = app.databasePhase();
    if (phase !== DatabasePhase.Setup) {
      app.setDatabasePhase(DatabasePhase.Setup);
    }
  }

  _openDatabase(ready) {
    if (this._db) {
      ready();
      return;
    }

    let mode = sqlite3.OPEN_READWRITE;
    if (NylasEnv.isWorkWindow()) {
      // Since only the main window calls \`_runDatabaseSetup\`, it's important that
      // it is also the only window with permission to create the file on disk
      mode = sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE;
    }

    this._db = new sqlite3.Database(this._databasePath, mode, (err) => {
      if (err) {
        this._handleSetupError(err);
        return;
      }

      // https://www.sqlite.org/wal.html
      // WAL provides more concurrency as readers do not block writers and a writer
      // does not block readers. Reading and writing can proceed concurrently.
      this._db.run(`PRAGMA journal_mode = WAL;`);

      // Note: These are properties of the connection, so they must be set regardless
      // of whether the database setup queries are run.

      // https://www.sqlite.org/intern-v-extern-blob.html
      // A database page size of 8192 or 16384 gives the best performance for large BLOB I/O.
      this._db.run(`PRAGMA main.page_size = 8192;`);
      this._db.run(`PRAGMA main.cache_size = 20000;`);
      this._db.run(`PRAGMA main.synchronous = NORMAL;`);
      this._db.configure('busyTimeout', 10000);
      this._db.on('profile', (query, msec) => {
        if (msec > 100) {
          this._prettyConsoleLog(`${msec}msec: ${query}`);
        } else {
          console.debug(DEBUG_TO_LOG, `${msec}: ${query}`);
        }
      });
      ready();
    });
  }

  _checkDatabaseVersion({allowNotSet} = {}, ready) {
    this._db.get('PRAGMA user_version', (err, result) => {
      if (err) {
        return this._handleSetupError(err)
      }
      const emptyVersion = (result.user_version === 0);
      const wrongVersion = (result.user_version / 1 !== DatabaseVersion);
      if (wrongVersion && !(emptyVersion && allowNotSet)) {
        return this._handleSetupError(new Error(`Incorrect database schema version: ${result.user_version} not ${DatabaseVersion}`));
      }
      return ready();
    });
  }

  _runDatabaseSetup(ready) {
    const builder = new DatabaseSetupQueryBuilder()

    this._db.serialize(() => {
      async.each(builder.setupQueries(), (query, callback) => {
        console.debug(DEBUG_TO_LOG, `DatabaseStore: ${query}`);
        this._db.run(query, [], callback);
      }, (err) => {
        if (err) {
          return this._handleSetupError(err);
        }
        return this._db.run(`PRAGMA user_version=${DatabaseVersion}`, (versionErr) => {
          if (versionErr) {
            return this._handleSetupError(versionErr);
          }

          const exportPath = path.join(NylasEnv.getConfigDirPath(), 'mail-rules-export.json')
          if (fs.existsSync(exportPath)) {
            try {
              const row = JSON.parse(fs.readFileSync(exportPath));
              this.inTransaction(t => t.persistJSONBlob('MailRules-V2', row.json));
              fs.unlink(exportPath);
            } catch (mailRulesError) {
              console.log(`Could not re-import mail rules: ${mailRulesError}`);
            }
          }
          return ready();
        });
      });
    });
  }

  _runDatabaseAnalyze() {
    const builder = new DatabaseSetupQueryBuilder();
    async.each(builder.analyzeQueries(), (query, callback) => {
      this._db.run(query, [], callback);
    }, (err) => {
      console.log(`Completed ANALYZE of database`, err);
    });
  }

  _handleSetupError(err = (new Error(`Manually called _handleSetupError`))) {
    NylasEnv.reportError(err, {}, {noWindows: true});

    // Temporary: export mail rules. They're the only bit of data in the cache
    // we can't rebuild. Should be moved to cloud metadata store soon.
    this._db.all(`SELECT * FROM JSONBlob WHERE id = 'MailRules-V2' LIMIT 1`, [], (mailsRulesErr, results = []) => {
      if (!mailsRulesErr && results.length === 1) {
        const exportPath = path.join(NylasEnv.getConfigDirPath(), 'mail-rules-export.json');
        try {
          fs.writeFileSync(exportPath, results[0].data);
        } catch (writeErr) {
          console.log(`Could not write mail rules to file: ${writeErr}`);
        }
      }

      const app = remote.getGlobal('application');
      app.rebuildDatabase();
    });
  }

  _prettyConsoleLog(qa) {
    let q = qa.replace(/%/g, '%%');
    q = `color:black |||%c ${q}`;
    q = q.replace(/`(\w+)`/g, "||| color:purple |||%c$&||| color:black |||%c");

    const colorRules = {
      'color:green': ['SELECT', 'INSERT INTO', 'VALUES', 'WHERE', 'FROM', 'JOIN', 'ORDER BY', 'DESC', 'ASC', 'INNER', 'OUTER', 'LIMIT', 'OFFSET', 'IN'],
      'color:red; background-color:#ffdddd;': ['SCAN TABLE'],
    };

    for (const style of Object.keys(colorRules)) {
      for (const keyword of colorRules[style]) {
        q = q.replace(new RegExp(`\\b${keyword}\\b`, 'g'), `||| ${style} |||%c${keyword}||| color:black |||%c`);
      }
    }

    q = q.split('|||');
    const colors = [];
    const msg = [];
    for (let i = 0; i < q.length; i ++) {
      if (i % 2 === 0) {
        colors.push(q[i]);
      } else {
        msg.push(q[i]);
      }
    }

    console.log(msg.join(''), ...colors);
  }

  // Returns a promise that resolves when the query has been completed and
  // rejects when the query has failed.
  //
  // If a query is made while the connection is being setup, the
  // DatabaseConnection will queue the queries and fire them after it has
  // been setup. The Promise returned here wont resolve until that happens
  _query(query, values = []) {
    return new Promise((resolve, reject) => {
      if (!this._open) {
        this._waiting.push(() => this._query(query, values).then(resolve, reject));
        return;
      }

      const fn = (query.indexOf(`SELECT `) === 0) ? 'all' : 'run';

      if (query.indexOf(`SELECT `) === 0) {
        if (DEBUG_QUERY_PLANS) {
          this._db.all(`EXPLAIN QUERY PLAN ${query}`, values, (err, results = []) => {
            const str = `${results.map(row => row.detail).join('\n')} for ${query}`;
            if (str.indexOf('ThreadCounts') > 0) {
              return;
            }
            if (str.indexOf('ThreadSearch') > 0) {
              return;
            }
            if ((str.indexOf('SCAN') !== -1) && (str.indexOf('COVERING INDEX') === -1)) {
              this._prettyConsoleLog(str);
            }
          });
        }
      }

      // Important: once the user begins a transaction, queries need to run
      // in serial.  This ensures that the subsequent `COMMIT` call
      // actually runs after the other queries in the transaction, and that
      // no other code can execute `BEGIN TRANS.` until the previously
      // queued BEGIN/COMMIT have been processed.

      // We don't exit serial execution mode until the last pending transaction has
      // finished executing.

      if (query.indexOf(`BEGIN`) === 0) {
        if (this._inflightTransactions === 0) {
          this._db.serialize();
        }
        this._inflightTransactions += 1;
      }

      this._db[fn](query, values, (err, results) => {
        if (err) {
          console.error(`DatabaseStore: Query ${query}, ${JSON.stringify(values)} failed ${err.toString()}`);
        }

        if (query === COMMIT) {
          this._inflightTransactions -= 1;
          if (this._inflightTransactions === 0) {
            this._db.parallelize();
          }
        }
        if (err) {
          reject(err)
        } else {
          resolve(results)
        }
      });
    });
  }

  // PUBLIC METHODS #############################

  // ActiveRecord-style Querying

  // Public: Creates a new Model Query for retrieving a single model specified by
  // the class and id.
  //
  // - \`class\` The class of the {Model} you're trying to retrieve.
  // - \`id\` The {String} id of the {Model} you're trying to retrieve
  //
  // Example:
  // ```coffee
  // DatabaseStore.find(Thread, 'id-123').then (thread) ->
  //   // thread is a Thread object, or null if no match was found.
  // ```
  //
  // Returns a {Query}
  //
  find(klass, id) {
    if (!klass) {
      throw new Error(`DatabaseStore::find - You must provide a class`);
    }
    if (typeof id !== 'string') {
      throw new Error(`DatabaseStore::find - You must provide a string id. You may have intended to use findBy.`);
    }
    return new Query(klass, this).where({id}).one();
  }

  // Public: Creates a new Model Query for retrieving a single model matching the
  // predicates provided.
  //
  // - \`class\` The class of the {Model} you're trying to retrieve.
  // - \`predicates\` An {Array} of {matcher} objects. The set of predicates the
  //    returned model must match.
  //
  // Returns a {Query}
  //
  findBy(klass, predicates = []) {
    if (!klass) {
      throw new Error(`DatabaseStore::findBy - You must provide a class`);
    }
    return new Query(klass, this).where(predicates).one();
  }

  // Public: Creates a new Model Query for retrieving all models matching the
  // predicates provided.
  //
  // - \`class\` The class of the {Model} you're trying to retrieve.
  // - \`predicates\` An {Array} of {matcher} objects. The set of predicates the
  //    returned model must match.
  //
  // Returns a {Query}
  //
  findAll(klass, predicates = []) {
    if (!klass) {
      throw new Error(`DatabaseStore::findAll - You must provide a class`);
    }
    return new Query(klass, this).where(predicates);
  }

  // Public: Creates a new Model Query that returns the {Number} of models matching
  // the predicates provided.
  //
  // - \`class\` The class of the {Model} you're trying to retrieve.
  // - \`predicates\` An {Array} of {matcher} objects. The set of predicates the
  //    returned model must match.
  //
  // Returns a {Query}
  //
  count(klass, predicates = []) {
    if (!klass) {
      throw new Error(`DatabaseStore::count - You must provide a class`);
    }
    return new Query(klass, this).where(predicates).count();
  }

  // Public: Modelify converts the provided array of IDs or models (or a mix of
  // IDs and models) into an array of models of the \`klass\` provided by querying for the missing items.
  //
  // Modelify is efficient and uses a single database query. It resolves Immediately
  // if no query is necessary.
  //
  // - \`class\` The {Model} class desired.
  // - 'arr' An {Array} with a mix of string model IDs and/or models.
  //
  modelify(klass, arr) {
    if (!(arr instanceof Array) || (arr.length === 0)) {
      return Promise.resolve([]);
    }

    const ids = []
    const clientIds = []
    for (const item of arr) {
      if (item instanceof klass) {
        if (!item.serverId) {
          clientIds.push(item.clientId);
        } else {
          continue;
        }
      } else if (typeof(item) === 'string') {
        if (Utils.isTempId(item)) {
          clientIds.push(item);
        } else {
          ids.push(item);
        }
      } else {
        throw new Error(`modelify: Not sure how to convert ${item} into a ${klass.name}`);
      }
    }
    if ((ids.length === 0) && (clientIds.length === 0)) {
      return Promise.resolve(arr);
    }

    const queries = {
      modelsFromIds: [],
      modelsFromClientIds: [],
    }

    if (ids.length) {
      queries.modelsFromIds = this.findAll(klass).where(klass.attributes.id.in(ids));
    }
    if (clientIds.length) {
      queries.modelsFromClientIds = this.findAll(klass).where(klass.attributes.clientId.in(clientIds));
    }

    return Promise.props(queries).then(({modelsFromIds, modelsFromClientIds}) => {
      const modelsByString = {};
      for (const model of modelsFromIds) {
        modelsByString[model.id] = model;
      }
      for (const model of modelsFromClientIds) {
        modelsByString[model.clientId] = model;
      }

      return Promise.resolve(arr.map(item =>
        (item instanceof klass ? item : modelsByString[item]))
      );
    });
  }

  // Public: Executes a {Query} on the local database.
  //
  // - \`modelQuery\` A {Query} to execute.
  //
  // Returns a {Promise} that
  //   - resolves with the result of the database query.
  //
  run(modelQuery, options = {format: true}) {
    return this._query(modelQuery.sql(), []).then((result) => {
      let transformed = modelQuery.inflateResult(result);
      if (options.format !== false) {
        transformed = modelQuery.formatResult(transformed)
      }
      return Promise.resolve(transformed);
    });
  }

  findJSONBlob(id) {
    JSONBlob = JSONBlob || require('../models/json-blob').default;
    return new JSONBlob.Query(JSONBlob, this).where({id}).one();
  }

  // Private: Mutation hooks allow you to observe changes to the database and
  // add additional functionality before and after the REPLACE / INSERT queries.
  //
  // beforeDatabaseChange: Run queries, etc. and return a promise. The DatabaseStore
  // will proceed with changes once your promise has finished. You cannot call
  // persistModel or unpersistModel from this hook.
  //
  // afterDatabaseChange: Run queries, etc. after the REPLACE / INSERT queries
  //
  // Warning: this is very low level. If you just want to watch for changes, You
  // should subscribe to the DatabaseStore's trigger events.
  //
  addMutationHook({beforeDatabaseChange, afterDatabaseChange}) {
    if (!beforeDatabaseChange) {
      throw new Error(`DatabaseStore:addMutationHook - You must provide a beforeDatabaseChange function`);
    }
    if (!afterDatabaseChange) {
      throw new Error(`DatabaseStore:addMutationHook - You must provide a afterDatabaseChange function`);
    }
    this._databaseMutationHooks.push({beforeDatabaseChange, afterDatabaseChange});
  }

  removeMutationHook(hook) {
    this._databaseMutationHooks = this._databaseMutationHooks.filter(h => h !== hook);
  }

  mutationHooks() {
    return this._databaseMutationHooks;
  }


  // Public: Opens a new database transaction for writing changes.
  // DatabaseStore.inTransacion makes the following guarantees:
  //
  // - No other calls to \`inTransaction\` will run until the promise has finished.
  //
  // - No other process will be able to write to sqlite while the provided function
  //   is running. `BEGIN IMMEDIATE TRANSACTION` semantics are:
  //     + No other connection will be able to write any changes.
  //     + Other connections can read from the database, but they will not see
  //       pending changes.
  //
  // this.param fn {function} callback that will be executed inside a database transaction
  // Returns a {Promise} that resolves when the transaction has successfully
  // completed.
  inTransaction(fn) {
    const t = new DatabaseTransaction(this);
    this._transactionQueue = this._transactionQueue || new PromiseQueue(1, Infinity);
    return this._transactionQueue.add(() =>
      t.execute(fn)
    );
  }

  // _accumulateAndTrigger is a guarded version of trigger that can accumulate changes.
  // This means that even if you're a bad person and call \`persistModel\` 100 times
  // from 100 task objects queued at the same time, it will only create one
  // \`trigger\` event. This is important since the database triggering impacts
  // the entire application.
  accumulateAndTrigger(change) {
    this._triggerPromise = this._triggerPromise || new Promise((resolve) => {
      this._resolve = resolve;
    });

    const flush = () => {
      if (!this._changeAccumulated) {
        return;
      }
      if (this._changeFireTimer) {
        clearTimeout(this._changeFireTimer);
      }
      this.trigger(new DatabaseChangeRecord(this._changeAccumulated));
      this._changeAccumulated = null;
      this._changeAccumulatedLookup = null;
      this._changeFireTimer = null;
      if (this._resolve) {
        this._resolve();
      }
      this._triggerPromise = null;
    };

    const set = (_change) => {
      if (this._changeFireTimer) {
        clearTimeout(this._changeFireTimer);
      }
      this._changeAccumulated = _change;
      this._changeAccumulatedLookup = {};
      this._changeAccumulated.objects.forEach((obj, idx) => {
        this._changeAccumulatedLookup[obj.id] = idx;
      });
      this._changeFireTimer = setTimeout(flush, 10);
    };

    const concat = (_change) => {
      // When we join new models into our set, replace existing ones so the same
      // model cannot exist in the change record set multiple times.
      for (const obj of _change.objects) {
        const idx = this._changeAccumulatedLookup[obj.id]
        if (idx) {
          this._changeAccumulated.objects[idx] = obj;
        } else {
          this._changeAccumulatedLookup[obj.id] = this._changeAccumulated.objects.length
          this._changeAccumulated.objects.push(obj);
        }
      }
    };

    if (!this._changeAccumulated) {
      set(change);
    } else if ((this._changeAccumulated.objectClass === change.objectClass) && (this._changeAccumulated.type === change.type)) {
      concat(change);
    } else {
      flush();
      set(change);
    }

    return this._triggerPromise;
  }


  // Search Index Operations

  createSearchIndexSql(klass) {
    if (!klass) {
      throw new Error(`DatabaseStore::createSearchIndex - You must provide a class`);
    }
    if (!klass.searchFields) {
      throw new Error(`DatabaseStore::createSearchIndex - ${klass.name} must expose an array of \`searchFields\``);
    }
    const searchTableName = `${klass.name}Search`;
    const searchFields = klass.searchFields;
    return (
      `CREATE VIRTUAL TABLE IF NOT EXISTS \`${searchTableName}\` ` +
      `USING fts5(
        tokenize='porter unicode61',
        content_id UNINDEXED,
        ${searchFields.join(', ')}
      )`
    );
  }

  createSearchIndex(klass) {
    const sql = this.createSearchIndexSql(klass);
    return this._query(sql);
  }

  searchIndexSize(klass) {
    const searchTableName = `${klass.name}Search`;
    const sql = `SELECT COUNT(content_id) as count FROM \`${searchTableName}\``;
    return this._query(sql).then((result) => result[0].count);
  }

  isIndexEmptyForAccount(accountId, modelKlass) {
    const modelTable = modelKlass.name
    const searchTable = `${modelTable}Search`
    const sql = (
      `SELECT \`${searchTable}\`.\`content_id\` FROM \`${searchTable}\` INNER JOIN \`${modelTable}\`
      ON \`${modelTable}\`.id = \`${searchTable}\`.\`content_id\` WHERE \`${modelTable}\`.\`account_id\` = ?
      LIMIT 1`
    );
    return this._query(sql, [accountId]).then(result => result.length === 0);
  }

  dropSearchIndex(klass) {
    if (!klass) {
      throw new Error(`DatabaseStore::createSearchIndex - You must provide a class`);
    }
    const searchTableName = `${klass.name}Search`
    const sql = `DROP TABLE IF EXISTS \`${searchTableName}\``
    return this._query(sql);
  }

  isModelIndexed(model, isIndexed) {
    if (isIndexed === true) {
      return Promise.resolve(true);
    }
    const searchTableName = `${model.constructor.name}Search`
    const exists = (
      `SELECT rowid FROM \`${searchTableName}\` WHERE \`${searchTableName}\`.\`content_id\` = ?`
    )
    return this._query(exists, [model.id]).then((results) =>
      Promise.resolve(results.length > 0)
    )
  }

  indexModel(model, indexData, isModelIndexed) {
    const searchTableName = `${model.constructor.name}Search`;
    return this.isModelIndexed(model, isModelIndexed).then((isIndexed) => {
      if (isIndexed) {
        return this.updateModelIndex(model, indexData, isIndexed);
      }

      const indexFields = Object.keys(indexData)
      const keysSql = `content_id, ${indexFields.join(`, `)}`
      const valsSql = `?, ${indexFields.map(() => '?').join(', ')}`
      const values = [model.id].concat(indexFields.map(k => indexData[k]))
      const sql = (
        `INSERT INTO \`${searchTableName}\`(${keysSql}) VALUES (${valsSql})`
      )
      return this._query(sql, values);
    });
  }

  updateModelIndex(model, indexData, isModelIndexed) {
    const searchTableName = `${model.constructor.name}Search`;
    this.isModelIndexed(model, isModelIndexed).then((isIndexed) => {
      if (!isIndexed) {
        return this.indexModel(model, indexData, isIndexed);
      }

      const indexFields = Object.keys(indexData);
      const values = indexFields.map(key => indexData[key]).concat([model.id]);
      const setSql = (
        indexFields
        .map((key) => `\`${key}\` = ?`)
        .join(', ')
      );
      const sql = (
        `UPDATE \`${searchTableName}\` SET ${setSql} WHERE \`${searchTableName}\`.\`content_id\` = ?`
      );
      return this._query(sql, values);
    });
  }

  unindexModel(model) {
    const searchTableName = `${model.constructor.name}Search`;
    const sql = (
      `DELETE FROM \`${searchTableName}\` WHERE \`${searchTableName}\`.\`content_id\` = ?`
    );
    return this._query(sql, [model.id]);
  }

  unindexModelsForAccount(accountId, modelKlass) {
    const modelTable = modelKlass.name;
    const searchTableName = `${modelTable}Search`;
    const sql = (
      `DELETE FROM \`${searchTableName}\` WHERE \`${searchTableName}\`.\`content_id\` IN
      (SELECT \`id\` FROM \`${modelTable}\` WHERE \`${modelTable}\`.\`account_id\` = ?)`
    );
    return this._query(sql, [accountId]);
  }
}

export default new DatabaseStore();
