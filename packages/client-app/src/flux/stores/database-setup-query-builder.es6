/* eslint global-require:0 */
import DatabaseObjectRegistry from '../../registries/database-object-registry';
import {tableNameForJoin} from '../models/utils';

import Attributes from '../attributes';
const {AttributeCollection, AttributeJoinedData} = Attributes;

// The DatabaseConnection dispatches queries to the Browser process via IPC and listens
// for results. It maintains a hash of `_queryRecords` representing queries that are
// currently running and fires promise callbacks when complete.
//
export default class DatabaseSetupQueryBuilder {

  setupQueries() {
    let queries = []
    for (const klass of DatabaseObjectRegistry.getAllConstructors()) {
      queries = queries.concat(this.setupQueriesForTable(klass));
    }
    return queries;
  }

  setupQueriesForTable(klass) {
    const attributes = Object.keys(klass.attributes).map(k => klass.attributes[k]);
    let queries = [];

    // Identify attributes of this class that can be matched against. These
    // attributes need their own columns in the table
    const columnAttributes = attributes.filter(attr => attr.needsColumn())

    const columns = ['id TEXT PRIMARY KEY', 'data BLOB']
    columnAttributes.forEach(attr => columns.push(attr.columnSQL()));

    const columnsSQL = columns.join(',');
    queries.unshift(`CREATE TABLE IF NOT EXISTS \`${klass.name}\` (${columnsSQL})`);
    queries.push(`CREATE UNIQUE INDEX IF NOT EXISTS \`${klass.name}_id\` ON \`${klass.name}\` (\`id\`)`);

    // Identify collection attributes that can be matched against. These require
    // JOIN tables. (Right now the only one of these is Thread.folders or
    // Thread.categories)
    const collectionAttributes = attributes.filter(attr =>
      attr.queryable && attr instanceof AttributeCollection
    );
    collectionAttributes.forEach((attribute) => {
      const joinTable = tableNameForJoin(klass, attribute.itemClass);
      const joinColumns = attribute.joinQueryableBy.map((name) =>
        klass.attributes[name].columnSQL()
      );
      joinColumns.unshift('id TEXT KEY', '`value` TEXT');

      queries.push(`CREATE TABLE IF NOT EXISTS \`${joinTable}\` (${joinColumns.join(',')})`);
      queries.push(`CREATE INDEX IF NOT EXISTS \`${joinTable.replace('-', '_')}_id\` ON \`${joinTable}\` (\`id\` ASC)`);
      queries.push(`CREATE UNIQUE INDEX IF NOT EXISTS \`${joinTable.replace('-', '_')}_val_id\` ON \`${joinTable}\` (\`value\` ASC, \`id\` ASC)`);
    });

    const joinedDataAttributes = attributes.filter(attr =>
      attr instanceof AttributeJoinedData
    )

    joinedDataAttributes.forEach((attribute) => {
      queries.push(`CREATE TABLE IF NOT EXISTS \`${attribute.modelTable}\` (id TEXT PRIMARY KEY, \`value\` TEXT)`);
    });

    if (klass.additionalSQLiteConfig && klass.additionalSQLiteConfig.setup) {
      queries = queries.concat(klass.additionalSQLiteConfig.setup());
    }

    if (klass.searchable === true) {
      const DatabaseStore = require('./database-store').default;
      queries.push(DatabaseStore.createSearchIndexSql(klass));
    }

    return queries;
  }
}
