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

    # https://www.sqlite.org/wal.html
    # WAL provides more concurrency as readers do not block writers and a writer
    # does not block readers. Reading and writing can proceed concurrently.
    queries.push "PRAGMA journal_mode = WAL;"
    # https://www.sqlite.org/intern-v-extern-blob.html
    # A database page size of 8192 or 16384 gives the best performance for large BLOB I/O.
    queries.push "PRAGMA main.page_size = 8192;"
    queries.push "PRAGMA main.cache_size = 20000;"
    queries.push "PRAGMA main.synchronous = NORMAL;"

    # Add table for storing generic JSON blobs
    queries.push("CREATE TABLE IF NOT EXISTS `JSONObject` (key TEXT PRIMARY KEY, data BLOB)")
    queries.push("CREATE UNIQUE INDEX IF NOT EXISTS `JSONObject_id` ON `JSONObject` (`key`)")

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
