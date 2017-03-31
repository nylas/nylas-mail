/* eslint global-require:0 */
import Model from '../models/model';
import ModelQuery from '../models/query';
import {tableNameForJoin, registeredObjectReplacer} from '../models/utils';

import Attributes from '../attributes';

const {AttributeCollection, AttributeJoinedData} = Attributes;

export default class DatabaseWriter {
  constructor(database) {
    this.database = database;
    this._changeRecords = [];
    this._opened = false;
  }

  find(...args) { return this._forwardOperationToDatabase('find', ...args) }
  findBy(...args) { return this._forwardOperationToDatabase('findBy', ...args) }
  findAll(...args) { return this._forwardOperationToDatabase('findAll', ...args) }
  modelify(...args) { return this._forwardOperationToDatabase('modelify', ...args) }
  count(...args) { return this._forwardOperationToDatabase('count', ...args) }
  findJSONBlob(...args) { return this._forwardOperationToDatabase('findJSONBlob', ...args) }

  execute(fn) {
    if (this._opened) {
      throw new Error("DatabaseWriter:execute was already called");
    }

    return this._query("BEGIN IMMEDIATE TRANSACTION").then(() => {
      this._opened = true;
      const transactionReturn = fn(this);
      if (!transactionReturn || !transactionReturn.then) {
        console.error(fn)
        throw new Error("The Database Transaction function shown above must return a Promise. It Returned:", transactionReturn)
      }
      return transactionReturn;
    }).finally(() => {
      if (!this._opened) {
        return null;
      }
      this._opened = false;
      return this._query("COMMIT").then(() => {
        for (const record of this._changeRecords) {
          this.database.accumulateAndTrigger(record);
        }
      });
    });
  }

  // Mutating the Database

  persistJSONBlob(id, json) {
    const JSONBlob = require('../models/json-blob').default;

    return this.persistModel(new JSONBlob({id, json}));
  }

  // Public: Asynchronously writes `model` to the cache and triggers a change event.
  //
  // - `model` A {Model} to write to the database.
  //
  // Returns a {Promise} that
  //   - resolves after the database queries are complete and any listening
  //     database callbacks have finished
  //   - rejects if any databse query fails or one of the triggering
  //     callbacks failed
  persistModel(model, opts = {}) {
    if (!model || !(model instanceof Model)) {
      throw new Error("DatabaseWriter::persistModel - You must pass an instance of the Model class.");
    }
    return this.persistModels([model], opts);
  }

  // Public: Asynchronously writes `models` to the cache and triggers a single change
  // event. Note: Models must be of the same class to be persisted in a batch operation.
  //
  // - `models` An {Array} of {Model} objects to write to the database.
  //
  // - options:
  //  - `silent`: default false. Will notify hooks and downstream
  //    listeners that the models have changed. Always have it set to
  //    false unless you're VERY sure no one needs to know about the
  //    changes that happen. This could cause DBs to become out of sync if
  //    careless.
  //  - `affectsJoins`: defaults to true. Any model that has joined
  //    properties via Attributes.Collections almost always needs to get
  //    updated. If you're VERY sure the change does not affect any join
  //    tables, you can set this to `false` to save some DB queries.
  //
  // Returns a {Promise} that
  //   - resolves after the database queries are complete and any listening
  //     database callbacks have finished
  //   - rejects if any databse query fails or one of the triggering
  //     callbacks failed
  persistModels(models = [], {silent = false, affectsJoins = true} = {}) {
    if (models.length === 0) {
      return Promise.resolve();
    }

    const klass = models[0].constructor;
    const clones = [];
    const ids = {};

    if (!(models[0] instanceof Model)) {
      throw new Error(`DatabaseWriter::persistModels - You must pass an array of items which descend from the Model class.`);
    }

    for (const model of models) {
      if (!model || (model.constructor !== klass)) {
        throw new Error(`DatabaseWriter::persistModels - When you batch persist objects, they must be of the same type`);
      }
      if (ids[model.id]) {
        throw new Error(`DatabaseWriter::persistModels - You must pass an array of models with different ids. ID ${model.id} is in the set multiple times.`)
      }
      clones.push(model.clone());
      ids[model.id] = true;
    }

    // Note: It's important that we clone the objects since other code could mutate
    // them during the save process. We want to guaruntee that the models you send to
    // persistModels are saved exactly as they were sent.
    const metadata = {
      objectClass: clones[0].constructor.name,
      objectIds: Object.keys(ids),
      objects: clones,
      type: 'persist',
    }

    if (silent) {
      return this._writeModels(clones, {affectsJoins})
    }
    return this._runMutationHooks('beforeDatabaseChange', metadata).then((data) => {
      return this._writeModels(clones, {affectsJoins}).then(() => {
        this._runMutationHooks('afterDatabaseChange', metadata, data);
        return this._changeRecords.push(metadata);
      });
    });
  }

  // Public: Asynchronously removes `model` from the cache and triggers a change event.
  //
  // - `model` A {Model} to write to the database.
  //
  // Returns a {Promise} that
  //   - resolves after the database queries are complete and any listening
  //     database callbacks have finished
  //   - rejects if any databse query fails or one of the triggering
  //     callbacks failed
  unpersistModel(model, {silent = false} = {}) {
    const clone = model.clone();
    const metadata = {
      objectClass: clone.constructor.name,
      objectIds: [clone.id],
      objects: [clone],
      type: 'unpersist',
    }

    if (silent) {
      return this._deleteModel(clone)
    }
    return this._runMutationHooks('beforeDatabaseChange', metadata).then((data) => {
      return this._deleteModel(clone).then(() => {
        this._runMutationHooks('afterDatabaseChange', metadata, data);
        return this._changeRecords.push(metadata);
      });
    });
  }

  removeAllOfClass(klass) {
    return this._query(`DELETE FROM ${klass.name}`)
  }

  // PRIVATE METHODS ////////////////////////////////////////////////////////

  _query = (...args) => {
    return this.database._query(...args);
  }

  _runMutationHooks(selectorName, metadata, data = []) {
    const beforePromises = this.database.mutationHooks().map((hook, idx) =>
      Promise.try(() => hook[selectorName](this._query, metadata, data[idx]))
    );

    return Promise.all(beforePromises).catch((e) => {
      if (!NylasEnv.inSpecMode()) {
        console.warn(`DatabaseWriter Hook: ${selectorName} failed`, e);
      }
      return Promise.resolve([]);
    });
  }

  // Fires the queries required to write models to the DB
  //
  // Returns a promise that:
  //   - resolves when all write queries are complete
  //   - rejects if any query fails
  _writeModels(models, {affectsJoins = true} = {}) {
    const promises = [];

    // IMPORTANT: This method assumes that all the models you
    // provide are of the same class, and have different ids!

    // Avoid trying to write too many objects a time - sqlite can only handle
    // value sets `(?,?)...` of less than SQLITE_MAX_COMPOUND_SELECT (500),
    // and we don't know ahead of time whether we'll hit that or not.
    if (models.length > 50) {
      return Promise.all([
        this._writeModels(models.slice(0, 50), {affectsJoins}),
        this._writeModels(models.slice(50), {affectsJoins}),
      ]);
    }

    const klass = models[0].constructor;
    const attributes = Object.keys(klass.attributes).map(key => klass.attributes[key])

    const columnAttributes = attributes.filter((attr) =>
      attr.queryable && attr.columnSQL && attr.jsonKey !== 'id'
    );

    // Compute the columns in the model table and a question mark string
    const columns = ['id', 'data'];
    const columnMarks = ['?', '?'];
    columnAttributes.forEach((attr) => {
      columns.push(attr.jsonKey);
      columnMarks.push('?');
    });
    const columnsSQL = columns.join(',');
    const marksSet = `(${columnMarks.join(',')})`;

    // Prepare a batch insert VALUES (?,?,?), (?,?,?)... by assembling
    // an array of the values and a corresponding question mark set
    const values = [];
    const marks = [];
    const ids = [];
    const modelsJSONs = [];
    for (const model of models) {
      const json = model.toJSON({joined: false});
      modelsJSONs.push(json);
      ids.push(model.id);
      values.push(model.id, JSON.stringify(json, registeredObjectReplacer));
      columnAttributes.forEach((attr) => {
        values.push(json[attr.jsonKey]);
      });
      marks.push(marksSet);
    }

    const marksSQL = marks.join(',');

    promises.push(this._query(`REPLACE INTO \`${klass.name}\` (${columnsSQL}) VALUES ${marksSQL}`, values));

    if (!affectsJoins) {
      return Promise.all(promises);
    }

    // For each join table property, find all the items in the join table for this
    // model and delete them. Insert each new value back into the table.
    const collectionAttributes = attributes.filter((attr) =>
      attr.queryable && attr instanceof AttributeCollection
    )

    collectionAttributes.forEach((attr) => {
      const joinTable = tableNameForJoin(klass, attr.itemClass);

      promises.push(this._query(`DELETE FROM \`${joinTable}\` WHERE \`id\` IN ('${ids.join("','")}')`));

      const joinMarks = [];
      const joinedValues = [];
      const joinMarkUnit = `(${["?", "?"].concat(attr.joinQueryableBy.map(() => '?')).join(',')})`;
      const joinQueryableByJSONKeys = attr.joinQueryableBy.map(joinedModelKey =>
        klass.attributes[joinedModelKey].jsonKey
      );
      const joinColumns = ['id', 'value'].concat(joinQueryableByJSONKeys);

      // https://www.sqlite.org/limits.html: SQLITE_MAX_VARIABLE_NUMBER
      const valuesPerRow = joinColumns.length;
      const rowsPerInsert = Math.floor(600 / valuesPerRow);
      const valuesPerInsert = rowsPerInsert * valuesPerRow;

      models.forEach((model, idx) => {
        const joinedModels = model[attr.modelKey] || [];
        for (const joined of joinedModels) {
          if (!attr.joinOnField) {
            throw new Error(`Queryable collection attribute ${attr.modelKey} must specify a joinOnField`);
          }
          const joinValue = joined[attr.joinOnField];
          joinMarks.push(joinMarkUnit);
          joinedValues.push(model.id, joinValue);
          for (const joinedJsonKey of joinQueryableByJSONKeys) {
            joinedValues.push(modelsJSONs[idx][joinedJsonKey]);
          }
        }
      });

      if (joinedValues.length !== 0) {
        // Write no more than 200 items (400 values) at once to avoid sqlite limits
        // 399 values: slices:[0..0]
        // 400 values: slices:[0..0]
        // 401 values: slices:[0..1]
        const slicePageCount = Math.ceil(joinMarks.length / rowsPerInsert) - 1;
        for (let slice = 0; slice <= slicePageCount; slice++) {
          const [ms, me] = [slice * rowsPerInsert, slice * rowsPerInsert + rowsPerInsert];
          const [vs, ve] = [slice * valuesPerInsert, slice * valuesPerInsert + valuesPerInsert];
          promises.push(this._query(`INSERT OR IGNORE INTO \`${joinTable}\` (\`${joinColumns.join('`,`')}\`) VALUES ${joinMarks.slice(ms, me).join(',')}`, joinedValues.slice(vs, ve)));
        }
      }
    });

    // For each joined data property stored in another table...
    const joinedDataAttributes = attributes.filter(attr =>
      attr instanceof AttributeJoinedData
    )

    joinedDataAttributes.forEach((attr) => {
      for (const model of models) {
        if (model[attr.modelKey] !== undefined) {
          promises.push(this._query(`REPLACE INTO \`${attr.modelTable}\` (\`id\`, \`value\`) VALUES (?, ?)`, [model.id, model[attr.modelKey]]));
        }
      }
    });

    return Promise.all(promises);
  }

  // Fires the queries required to delete models to the DB
  //
  // Returns a promise that:
  //   - resolves when all deltion queries are complete
  //   - rejects if any query fails
  _deleteModel(model) {
    const promises = []

    const klass = model.constructor;
    const attributes = Object.keys(klass.attributes).map(key => klass.attributes[key]);

    // Delete the primary record
    promises.push(this._query(`DELETE FROM \`${klass.name}\` WHERE \`id\` = ?`, [model.id]))

    // For each join table property, find all the items in the join table for this
    // model and delte them. Insert each new value back into the table.
    const collectionAttributes = attributes.filter(attr =>
      attr.queryable && attr instanceof AttributeCollection
    );

    collectionAttributes.forEach((attr) => {
      const joinTable = tableNameForJoin(klass, attr.itemClass);
      promises.push(this._query(`DELETE FROM \`${joinTable}\` WHERE \`id\` = ?`, [model.id]))
    });

    const joinedDataAttributes = attributes.filter(attr =>
      attr instanceof AttributeJoinedData
    );

    joinedDataAttributes.forEach((attr) => {
      promises.push(this._query(`DELETE FROM \`${attr.modelTable}\` WHERE \`id\` = ?`, [model.id]));
    });

    return Promise.all(promises);
  }

  _forwardOperationToDatabase(operation, ...args) {
    try {
      const query = this.database[operation](...args)
      if (query instanceof ModelQuery) {
        return query.markNotBackgroundable()
      }
      return query
    } catch (error) {
      throw new Error(`DatabaseWriter: Error trying to perform ${operation} on database. Is it defined?`)
    }
  }
}
