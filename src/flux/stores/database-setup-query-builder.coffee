_ = require 'underscore'
{AttributeCollection, AttributeJoinedData} = require '../attributes'

{modelClassMap,
 tableNameForJoin} = require '../models/utils'

# The DatabaseConnection dispatches queries to the Browser process via IPC and listens
# for results. It maintains a hash of `_queryRecords` representing queries that are
# currently running and fires promise callbacks when complete.
#
class DatabaseSetupQueryBuilder

  setupQueries: ->
    queries = []
    queries.push "PRAGMA journal_mode=WAL;"
    for key, klass of modelClassMap()
      continue unless klass.attributes
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
    # Thread.labels)
    collectionAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr instanceof AttributeCollection
    collectionAttributes.forEach (attribute) ->
      joinTable = tableNameForJoin(klass, attribute.itemClass)
      joinIndexName = "#{joinTable.replace('-', '_')}_id_val"
      queries.push("CREATE TABLE IF NOT EXISTS `#{joinTable}` (id TEXT KEY, `value` TEXT)")
      queries.push("CREATE UNIQUE INDEX IF NOT EXISTS `#{joinIndexName}` ON `#{joinTable}` (`id`,`value`)")

    joinedDataAttributes = _.filter attributes, (attr) ->
      attr instanceof AttributeJoinedData
    joinedDataAttributes.forEach (attribute) ->
      queries.push("CREATE TABLE IF NOT EXISTS `#{attribute.modelTable}` (id TEXT PRIMARY KEY, `value` TEXT)")

    if klass.additionalSQLiteConfig?.setup?
      queries = queries.concat(klass.additionalSQLiteConfig.setup())
    queries

module.exports = DatabaseSetupQueryBuilder
