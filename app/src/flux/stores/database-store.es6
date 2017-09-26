/* eslint global-require: 0 */
import path from 'path';
import createDebug from 'debug';
import childProcess from 'child_process';
import LRU from 'lru-cache';
import Sqlite3 from 'better-sqlite3';
import { remote } from 'electron';
import { ExponentialBackoffScheduler } from '../../backoff-schedulers';

import NylasStore from '../../global/nylas-store';
import Utils from '../models/utils';
import Query from '../models/query';
import DatabaseChangeRecord from './database-change-record';

const debug = createDebug('app:RxDB');
const debugVerbose = createDebug('app:RxDB:all');

const DEBUG_QUERY_PLANS = AppEnv.inDevMode();

const BASE_RETRY_LOCK_DELAY = 50;
const MAX_RETRY_LOCK_DELAY = 500;

function trimTo(str, size) {
  const g = window || global || {};
  const TRIM_SIZE = size || process.env.TRIM_SIZE || g.TRIM_SIZE || 256;
  let trimed = str;
  if (str.length >= TRIM_SIZE) {
    trimed = `${str.slice(0, TRIM_SIZE / 2)}…${str.slice(str.length - TRIM_SIZE / 2, str.length)}`;
  }
  return trimed;
}

function handleUnrecoverableDatabaseError(
  err = new Error(`Manually called handleUnrecoverableDatabaseError`)
) {
  AppEnv.errorLogger.reportError(err);
  const app = remote.getGlobal('application');
  if (!app) {
    throw new Error('handleUnrecoverableDatabaseError: `app` is not ready!');
  }
  app.rebuildDatabase({ detail: err.toString() });
}

async function openDatabase(dbPath) {
  try {
    const database = await new Promise((resolve, reject) => {
      const db = new Sqlite3(dbPath, { readonly: true });
      db.on('close', reject);
      db.on('open', () => {
        // https://www.sqlite.org/wal.html
        // WAL provides more concurrency as readers do not block writers and a writer
        // does not block readers. Reading and writing can proceed concurrently.
        db.pragma(`journal_mode = WAL`);

        // Note: These are properties of the connection, so they must be set regardless
        // of whether the database setup queries are run.

        // https://www.sqlite.org/intern-v-extern-blob.html
        // A database page size of 8192 or 16384 gives the best performance for large BLOB I/O.
        db.pragma(`main.page_size = 8192`);
        db.pragma(`main.cache_size = 20000`);
        db.pragma(`main.synchronous = NORMAL`);

        resolve(db);
      });
    });
    return database;
  } catch (err) {
    handleUnrecoverableDatabaseError(err);
    return null;
  }
}

function databasePath(configDirPath, specMode = false) {
  let dbPath = path.join(configDirPath, 'edgehill.db');
  if (specMode) {
    dbPath = path.join(configDirPath, 'edgehill.test.db');
  }
  return dbPath;
}

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

    this._open = false;
    this._waiting = [];
    this._preparedStatementCache = LRU({ max: 500 });

    this.setupEmitter();
    this._emitter.setMaxListeners(100);

    this._databasePath = databasePath(AppEnv.getConfigDirPath(), AppEnv.inSpecMode());

    if (!AppEnv.inSpecMode()) {
      this.open();
    }
  }

  async open() {
    this._db = await openDatabase(this._databasePath);
    this._open = true;
    for (const w of this._waiting) {
      w();
    }
    this._waiting = [];
    this._emitter.emit('ready');
  }

  _prettyConsoleLog(qa) {
    let q = qa.replace(/%/g, '%%');
    q = `color:black |||%c ${q}`;
    q = q.replace(/`(\w+)`/g, '||| color:purple |||%c$&||| color:black |||%c');

    const colorRules = {
      'color:green': [
        'SELECT',
        'INSERT INTO',
        'VALUES',
        'WHERE',
        'FROM',
        'JOIN',
        'ORDER BY',
        'DESC',
        'ASC',
        'INNER',
        'OUTER',
        'LIMIT',
        'OFFSET',
        'IN',
      ],
      'color:red; background-color:#ffdddd;': ['SCAN TABLE'],
    };

    for (const style of Object.keys(colorRules)) {
      for (const keyword of colorRules[style]) {
        q = q.replace(
          new RegExp(`\\b${keyword}\\b`, 'g'),
          `||| ${style} |||%c${keyword}||| color:black |||%c`
        );
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
    return new Promise(async (resolve, reject) => {
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

      const start = Date.now();

      if (!background) {
        const results = await this._executeLocally(query, values);
        const msec = Date.now() - start;
        if (msec > 100) {
          this._prettyConsoleLog(
            `DatabaseStore._executeLocally took more than 100ms - ${msec}msec: ${query}`
          );
        }
        resolve(results);
      } else {
        this._executeInBackground(query, values).then(({ results, backgroundTime }) => {
          const msec = Date.now() - start;
          if (debugVerbose.enabled) {
            const q = `🔶 (${msec}ms) Background: ${query}`;
            debugVerbose(trimTo(q));
          }

          if (msec > 100) {
            const msgPrefix =
              msec > 100 ? 'DatabaseStore._executeInBackground took more than 100ms - ' : '';
            this._prettyConsoleLog(
              `${msgPrefix}${msec}msec (${backgroundTime}msec in background): ${query}`
            );
          }
          resolve(results);
        });
      }
    });
  }

  async _executeLocally(query, values) {
    const fn = query.startsWith('SELECT') ? 'all' : 'run';
    let results = null;
    const scheduler = new ExponentialBackoffScheduler({
      baseDelay: BASE_RETRY_LOCK_DELAY,
      maxDelay: MAX_RETRY_LOCK_DELAY,
    });

    const schemaChangedStr = 'database schema has changed';

    const retryableRegexp = new RegExp(`(database is locked)||(${schemaChangedStr})`, 'i');

    // Because other processes may be writing to the database and modifying the
    // schema (running ANALYZE, etc.), we may `prepare` a statement and then be
    // unable to execute it. Handle this case silently unless it's persistent.
    while (!results) {
      try {
        if (scheduler.currentDelay() > 0) {
          // Setting a timeout for 0 will still defer execution of this function
          // to the next tick of the event loop.
          // We don't want to unnecessarily defer and delay every single query,
          // so we only set the timer when we are actually backing off for a
          // retry.
          await new Promise(resolve => setTimeout(resolve, scheduler.currentDelay()));
        }

        let stmt = this._preparedStatementCache.get(query);
        if (!stmt) {
          stmt = this._db.prepare(query);
          this._preparedStatementCache.set(query, stmt);
        }

        const start = Date.now();
        results = stmt[fn](values);
        const msec = Date.now() - start;
        if (debugVerbose.enabled) {
          const q = `(${msec}ms) ${query}`;
          debugVerbose(trimTo(q));
        }

        if (msec > 100) {
          const msgPrefix = msec > 100 ? 'DatabaseStore: query took more than 100ms - ' : '';
          if (query.startsWith(`SELECT `) && DEBUG_QUERY_PLANS) {
            const plan = this._db.prepare(`EXPLAIN QUERY PLAN ${query}`).all(values);
            const planString = `${plan.map(row => row.detail).join('\n')} for ${query}`;
            const quiet = ['ThreadCounts', 'ThreadSearch', 'ContactSearch', 'COVERING INDEX'];

            if (!quiet.find(str => planString.includes(str))) {
              this._prettyConsoleLog(`${msgPrefix}${msec}msec: ${planString}`);
            }
          } else {
            this._prettyConsoleLog(`${msgPrefix}${msec}msec: ${query}`);
          }
        }
      } catch (err) {
        const errString = err.toString();
        if (/database disk image is malformed/gi.test(errString)) {
          handleUnrecoverableDatabaseError(err);
          return results;
        }

        if (scheduler.numTries() > 5 || !retryableRegexp.test(errString)) {
          throw new Error(
            `DatabaseStore: Query ${query}, ${JSON.stringify(values)} failed ${err.toString()}`
          );
        }

        // Some errors require action before the query can be retried
        if (new RegExp(schemaChangedStr, 'i').test(errString)) {
          this._preparedStatementCache.del(query);
        }
      }
      scheduler.nextDelay();
    }
    return results;
  }

  _executeInBackground(query, values) {
    if (!this._agent) {
      this._agentOpenQueries = {};
      this._agent = childProcess.fork(
        path.join(path.dirname(__filename), 'database-agent.js'),
        [],
        {
          silent: true,
        }
      );
      this._agent.stdout.on('data', data => console.log(data.toString()));
      this._agent.stderr.on('data', data => console.error(data.toString()));
      this._agent.on('close', code => {
        debug(`Query Agent: exited with code ${code}`);
        this._agent = null;
      });
      this._agent.on('error', err => {
        console.error(`Query Agent: failed to start or receive message: ${err.toString()}`);
        this._agent.kill('SIGTERM');
        this._agent = null;
      });
      this._agent.on('message', ({ type, id, results, agentTime }) => {
        if (type === 'results') {
          this._agentOpenQueries[id]({ results, backgroundTime: agentTime });
          delete this._agentOpenQueries[id];
        }
      });
    }
    return new Promise(resolve => {
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
      throw new Error(
        `DatabaseStore::find - You must provide a string id. You may have intended to use findBy.`
      );
    }
    return new Query(klass, this).where({ id }).one();
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
    if (!(arr instanceof Array) || arr.length === 0) {
      return Promise.resolve([]);
    }

    const ids = [];
    for (const item of arr) {
      if (item instanceof klass) {
        // nothing
      } else if (typeof item === 'string') {
        ids.push(item);
      } else {
        throw new Error(`modelify: Not sure how to convert ${item} into a ${klass.name}`);
      }
    }
    if (ids.length === 0) {
      return Promise.resolve(arr);
    }

    return this.findAll(klass)
      .where(klass.attributes.id.in(ids))
      .markNotBackgroundable()
      .then(modelsFromIds => {
        const modelsByString = {};
        for (const model of modelsFromIds) {
          modelsByString[model.id] = model;
        }
        return Promise.resolve(
          arr.map(item => (item instanceof klass ? item : modelsByString[item]))
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
  run(modelQuery, options = { format: true }) {
    return this._query(
      modelQuery.sql(),
      [],
      modelQuery._background,
      modelQuery._logQueryPlanDebugOutput
    ).then(result => {
      let transformed = modelQuery.inflateResult(result);
      if (options.format !== false) {
        transformed = modelQuery.formatResult(transformed);
      }
      return Promise.resolve(transformed);
    });
  }

  inTransaction() {
    throw new Error('The client-side database connection no longer permits writes');
  }
}

export default new DatabaseStore();
