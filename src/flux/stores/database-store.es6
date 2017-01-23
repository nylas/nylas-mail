/* eslint global-require: 0 */
import path from 'path';
import fs from 'fs';
import Sqlite3 from 'better-sqlite3';
import childProcess from 'child_process';
import PromiseQueue from 'promise-queue';
import {remote, ipcRenderer} from 'electron';
import LRU from "lru-cache";

import NylasStore from '../../global/nylas-store';
import Utils from '../models/utils';
import Query from '../models/query';
import Actions from '../actions'
import DatabaseChangeRecord from './database-change-record';
import DatabaseTransaction from './database-transaction';
import DatabaseSetupQueryBuilder from './database-setup-query-builder';

const DatabaseVersion = "23";
const DatabasePhase = {
  Setup: 'setup',
  Ready: 'ready',
  Close: 'close',
}

const DEBUG_TO_LOG = false;
const DEBUG_QUERY_PLANS = NylasEnv.inDevMode();

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

    this._preparedStatementCache = LRU({max: 500});

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
        this._checkDatabaseVersion({allowUnset: true}, () => {
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

    this._db = new Sqlite3(this._databasePath, {});
    this._db.on('close', (err) => {
      NylasEnv.showErrorDialog({
        title: `Unable to open SQLite database at ${this._databasePath}`,
        message: err.toString(),
      });
      this._handleSetupError(err);
    })
    this._db.on('open', () => {
      // https://www.sqlite.org/wal.html
      // WAL provides more concurrency as readers do not block writers and a writer
      // does not block readers. Reading and writing can proceed concurrently.
      this._db.pragma(`journal_mode = WAL`);

      // Note: These are properties of the connection, so they must be set regardless
      // of whether the database setup queries are run.

      // https://www.sqlite.org/intern-v-extern-blob.html
      // A database page size of 8192 or 16384 gives the best performance for large BLOB I/O.
      this._db.pragma(`main.page_size = 8192`);
      this._db.pragma(`main.cache_size = 20000`);
      this._db.pragma(`main.synchronous = NORMAL`);

      ready();
    });
  }

  _checkDatabaseVersion({allowUnset} = {}, ready) {
    const result = this._db.pragma('user_version', true);
    const isUnsetVersion = (result === '0');
    const isWrongVersion = (result !== DatabaseVersion);
    if (isWrongVersion && !(isUnsetVersion && allowUnset)) {
      return this._handleSetupError(new Error(`Incorrect database schema version: ${result} not ${DatabaseVersion}`));
    }
    return ready();
  }

  _runDatabaseSetup(ready) {
    const builder = new DatabaseSetupQueryBuilder()

    try {
      for (const query of builder.setupQueries()) {
        console.debug(DEBUG_TO_LOG, `DatabaseStore: ${query}`);
        this._db.prepare(query).run();
      }
    } catch (err) {
      return this._handleSetupError(err);
    }

    this._db.pragma(`user_version=${DatabaseVersion}`);

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
  }

  _runDatabaseAnalyze() {
    const builder = new DatabaseSetupQueryBuilder();
    const queries = builder.analyzeQueries();
    const step = () => {
      const query = queries.shift();
      if (query) {
        console.debug(DEBUG_TO_LOG, `DatabaseStore: ${query}`);
        this._executeInAgent(query, []).then(step);
      } else {
        console.log(`Completed ANALYZE of database`);
      }
    }
    step();
  }

  _handleSetupError(err = (new Error(`Manually called _handleSetupError`))) {
    NylasEnv.reportError(err, {}, {noWindows: true});

    // Temporary: export mail rules. They're the only bit of data in the cache
    // we can't rebuild. Should be moved to cloud metadata store soon.
    if (this._db.open) {
      try {
        const result = this._db.prepare(`SELECT * FROM JSONBlob WHERE id = 'MailRules-V2' LIMIT 1`).get();
        if (result) {
          const exportPath = path.join(NylasEnv.getConfigDirPath(), 'mail-rules-export.json');
          try {
            fs.writeFileSync(exportPath, result.data);
          } catch (writeErr) {
            console.log(`Could not write mail rules to file: ${writeErr}`);
          }
        }
      } catch (dberr) {
        console.error(`Unable to save mail rules: ${dberr}`)
      }
    }
    const app = remote.getGlobal('application');
    app.rebuildDatabase();
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
    for (let i = 0; i < q.length; i++) {
      if (i % 2 === 0) {
        colors.push(q[i]);
      } else {
        msg.push(q[i]);
      }
    }

    console.log(msg.join(''), ...colors);
  }

  // Returns a Promise that resolves when the query has been completed and
  // rejects when the query has failed.
  //
  // If a query is made before the database has been opened, the query will be
  // held in a queue and run / resolved when the database is ready.
  _query(query, values = [], background = false) {
    return new Promise((resolve, reject) => {
      if (!this._open) {
        this._waiting.push(() => this._query(query, values).then(resolve, reject));
        return;
      }

      // Undefined, True, and False are not valid SQLite datatypes:
      // https://www.sqlite.org/datatype3.html
      values.forEach((val, idx) => {
        if (val === false) {
          values[idx] = 0;
        } else if (val === true) {
          values[idx] = 1;
        } else if (val === undefined) {
          values[idx] = null;
        }
      });

      if (query.startsWith(`SELECT `) && DEBUG_QUERY_PLANS) {
        const plan = this._db.prepare(`EXPLAIN QUERY PLAN ${query}`).all(values);
        const planString = `${plan.map(row => row.detail).join('\n')} for ${query}`;
        const quiet = ['ThreadCounts', 'ThreadSearch', 'ContactSearch', 'COVERING INDEX'];

        if (planString.includes('SCAN') && !quiet.find(str => planString.includes(str))) {
          console.log("Consider setting the .background() flag on this query to avoid blocking the event loop:")
          this._prettyConsoleLog(planString);
        }
      }

      const start = Date.now();

      if (!background) {
        const results = this._executeLocally(query, values);
        const msec = Date.now() - start;
        if ((msec > 100) || DEBUG_TO_LOG) {
          this._prettyConsoleLog(`${msec}msec: ${query}`);
        }
        resolve(results);
      } else {
        const forbidden = ['INSERT ', 'UPDATE ', 'DELETE ', 'DROP ', 'ALTER ', 'CREATE '];
        for (const key of forbidden) {
          if (query.startsWith(key)) {
            throw new Error("Transactional queries cannot be made in the database agent because they would not execute in the current transaction.")
          }
        }
        this._executeInAgent(query, values).then(({results, agentTime}) => {
          const msec = Date.now() - start;
          const overhead = msec - agentTime;
          if ((msec > 100) || (overhead > 0) || DEBUG_TO_LOG) {
            this._prettyConsoleLog(`${msec}msec (${agentTime}msec in agent): ${query}`);
          }
          resolve(results);
        });
      }
    });
  }

  _executeLocally(query, values) {
    const fn = query.startsWith('SELECT') ? 'all' : 'run';
    let tries = 0;
    let results = null;

    // Because other processes may be writing to the database and modifying the
    // schema (running ANALYZE, etc.), we may `prepare` a statement and then be
    // unable to execute it. Handle this case silently unless it's persistent.
    while (!results) {
      try {
        let stmt = this._preparedStatementCache.get(query);
        if (!stmt) {
          stmt = this._db.prepare(query);
          this._preparedStatementCache.set(query, stmt)
        }
        results = stmt[fn](values);
      } catch (err) {
        const errString = err.toString()
        if (/database disk image is malformed/gi.test(errString)) {
          // This is unrecoverable. We have to do a full database reset
          NylasEnv.reportError(err)
          Actions.resetEmailCache()
        } else if (tries < 3 && /database schema has changed/gi.test(errString)) {
          this._preparedStatementCache.del(query);
          tries += 1;
        } else {
          // note: this function may throw a promise, which causes our Promise to reject
          throw new Error(`DatabaseStore: Query ${query}, ${JSON.stringify(values)} failed ${err.toString()}`);
        }
      }
    }

    return results;
  }

  _executeInAgent(query, values) {
    if (!this._agent) {
      console.log("DatabaseAgent: Starting...");

      this._agentOpenQueries = {};
      this._agent = childProcess.fork(path.join(path.dirname(__filename), 'database-agent.js'), [], {
        silent: true,
      });
      this._agent.stdout.on('data', (data) =>
        console.log(data.toString())
      );
      this._agent.stderr.on('data', (data) =>
        console.error(data.toString())
      );
      this._agent.on('close', (code) => {
        console.debug(DEBUG_TO_LOG, `Query Agent: exited with code ${code}`);
        this._agent = null;
      });
      this._agent.on('error', (err) => {
        console.error(DEBUG_TO_LOG, `Query Agent: failed to start or receive message: ${err.toString()}`);
        this._agent.kill('SIGTERM');
        this._agent = null;
      });
      this._agent.on('message', ({type, id, results, agentTime}) => {
        if (type === 'results') {
          this._agentOpenQueries[id]({results, agentTime});
          delete this._agentOpenQueries[id];
        }
      });
    }
    return new Promise((resolve) => {
      const id = Utils.generateTempId();
      this._agentOpenQueries[id] = resolve;
      this._agent.send({ query, values, id, dbpath: this._databasePath });
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
      } else if (typeof item === 'string') {
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
      queries.modelsFromIds = this.findAll(klass).where(klass.attributes.id.in(ids)).markNotBackgroundable();
    }
    if (clientIds.length) {
      queries.modelsFromClientIds = this.findAll(klass).where(klass.attributes.clientId.in(clientIds)).markNotBackgroundable();
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
    return this._query(modelQuery.sql(), [], modelQuery._background).then((result) => {
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
    const dropSql = `DROP TABLE IF EXISTS \`${searchTableName}\``
    const clearIsSearchIndexedSql = `UPDATE \`${klass.name}\` SET \`is_search_indexed\` = 0 WHERE \`is_search_indexed\` = 1`
    return this._query(dropSql).then(() => {
      return this._query(clearIsSearchIndexedSql);
    });
  }

  isModelIndexed(model, isIndexed) {
    if (isIndexed === true) {
      return Promise.resolve(true);
    }
    return Promise.resolve(!!model.isSearchIndexed);
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
      return this._query(sql, values).then(() => {
        model.isSearchIndexed = true;
        return this.inTransaction((t) => t.persistModel(model))
      });
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

  // opts can have a boolean isBeingUnpersisted value, which when true prevents
  // this function from re-persisting the model.
  unindexModel(model, opts) {
    const searchTableName = `${model.constructor.name}Search`;
    const sql = (
      `DELETE FROM \`${searchTableName}\` WHERE \`${searchTableName}\`.\`content_id\` = ?`
    );
    const query = this._query(sql, [model.id]);
    if (opts.isBeingUnpersisted) {
      return query;
    }
    return query.then(() => {
      model.isSearchIndexed = false;
      return this.inTransaction((t) => t.persistModel(model))
    });
  }

  unindexModelsForAccount() {
    // const modelTable = modelKlass.name;
    // const searchTableName = `${modelTable}Search`;
    /* TODO: We don't correctly clean up the model tables right now, so we don't
     * want to destroy the index until we do so.
    const sql = (
      `DELETE FROM \`${searchTableName}\` WHERE \`${searchTableName}\`.\`content_id\` IN
      (SELECT \`id\` FROM \`${modelTable}\` WHERE \`${modelTable}\`.\`account_id\` = ?)`
    );
    return this._query(sql, [accountId])
   */
    return Promise.resolve()
  }
}

export default new DatabaseStore();
