_ = require 'underscore'
{AttributeCollection, AttributeJoinedData} = require '../attributes'

DatabaseObjectRegistry = require '../../database-object-registry'
{tableNameForJoin} = require '../models/utils'

# The DatabaseConnection dispatches queries to the Browser process via IPC and listens
# for results. It maintains a hash of `_queryRecords` representing queries that are
# currently running and fires promise callbacks when complete.
#
class DatabaseSetupQueryBuilder

  setupQueries: ->
    queries = []
    for key, klass of DatabaseObjectRegistry.classMap()
      queries = queries.concat @setupQueriesForTable(klass)
    return queries

  setupQueriesForTable: (klass) =>
    attributes = _.values(klass.attributes)
    queries = []

    # Identify attributes of this class that can be matched against. These
    # attributes need their own columns in the table
    columnAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr.columnSQL && attr.jsonKey != 'id'

    columns = ['id TEXT PRIMARY KEY', 'data BLOB']
    columnAttributes.forEach (attr) ->
      columns.push(attr.columnSQL())

    columnsSQL = columns.join(',')
    queries.unshift("CREATE TABLE IF NOT EXISTS `#{klass.name}` (#{columnsSQL})")
    queries.push("CREATE UNIQUE INDEX IF NOT EXISTS `#{klass.name}_id` ON `#{klass.name}` (`id`)")

    # Identify collection attributes that can be matched against. These require
    # JOIN tables. (Right now the only one of these is Thread.folders or
    # Thread.categories)
    collectionAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr instanceof AttributeCollection
    collectionAttributes.forEach (attribute) ->
      joinTable = tableNameForJoin(klass, attribute.itemClass)
      queries.push("CREATE TABLE IF NOT EXISTS `#{joinTable}` (id TEXT KEY, `value` TEXT)")
      queries.push("CREATE INDEX IF NOT EXISTS `#{joinTable.replace('-', '_')}_id` ON `#{joinTable}` (`id` ASC)")
      queries.push("CREATE UNIQUE INDEX IF NOT EXISTS `#{joinTable.replace('-', '_')}_val_id` ON `#{joinTable}` (`value` ASC, `id` ASC)")

    joinedDataAttributes = _.filter attributes, (attr) ->
      attr instanceof AttributeJoinedData
    joinedDataAttributes.forEach (attribute) ->
      queries.push("CREATE TABLE IF NOT EXISTS `#{attribute.modelTable}` (id TEXT PRIMARY KEY, `value` TEXT)")

    if klass.additionalSQLiteConfig?.setup?
      queries = queries.concat(klass.additionalSQLiteConfig.setup())

    if klass.searchable is true
      DatabaseStore = require './database-store'
      queries.push(DatabaseStore.createSearchIndexSql(klass))

    return queries

module.exports = DatabaseSetupQueryBuilder
