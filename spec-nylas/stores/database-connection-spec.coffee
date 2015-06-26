ipc = require 'ipc'
TestModel = require '../fixtures/db-test-model'
Attributes = require '../../src/flux/attributes'
DatabaseConnection = require '../../src/flux/stores/database-connection'

describe "DatabaseConnection", ->
  beforeEach ->
    @connection = new DatabaseConnection()
    # Emulate a working DB
    spyOn(ipc, 'send').andCallFake (messageType, {queryKey}) ->
      return unless messageType is "database-query"
      err = null
      result = []
      @connection._onDatabaseResult({queryKey, err, result})

  describe "_setupQueriesForTable", ->
    it "should return the queries for creating the table and the primary unique index", ->
      TestModel.attributes =
        'attrQueryable': Attributes.DateTime
          queryable: true
          modelKey: 'attrQueryable'
          jsonKey: 'attr_queryable'

        'attrNonQueryable': Attributes.Collection
          modelKey: 'attrNonQueryable'
          jsonKey: 'attr_non_queryable'
      queries = @connection._setupQueriesForTable(TestModel)
      expected = [
        'CREATE TABLE IF NOT EXISTS `TestModel` (id TEXT PRIMARY KEY,data BLOB,attr_queryable INTEGER)',
        'CREATE UNIQUE INDEX IF NOT EXISTS `TestModel_id` ON `TestModel` (`id`)'
      ]
      for query,i in queries
        expect(query).toBe(expected[i])

    it "should correctly create join tables for models that have queryable collections", ->
      TestModel.configureWithCollectionAttribute()
      queries = @connection._setupQueriesForTable(TestModel)
      expected = [
        'CREATE TABLE IF NOT EXISTS `TestModel` (id TEXT PRIMARY KEY,data BLOB)',
        'CREATE UNIQUE INDEX IF NOT EXISTS `TestModel_id` ON `TestModel` (`id`)',
        'CREATE TABLE IF NOT EXISTS `TestModel-Tag` (id TEXT KEY, `value` TEXT)'
        'CREATE UNIQUE INDEX IF NOT EXISTS `TestModel_Tag_id_val` ON `TestModel-Tag` (`id`,`value`)',
      ]
      for query,i in queries
        expect(query).toBe(expected[i])

    it "should use the correct column type for each attribute", ->
      TestModel.configureWithAllAttributes()
      queries = @connection._setupQueriesForTable(TestModel)
      expect(queries[0]).toBe('CREATE TABLE IF NOT EXISTS `TestModel` (id TEXT PRIMARY KEY,data BLOB,datetime INTEGER,string-json-key TEXT,boolean INTEGER,number INTEGER)')

    describe "when the model provides additional sqlite config", ->
      it "the setup method should return these queries", ->
        TestModel.configureWithAdditionalSQLiteConfig()
        spyOn(TestModel.additionalSQLiteConfig, 'setup').andCallThrough()
        queries = @connection._setupQueriesForTable(TestModel)
        expect(TestModel.additionalSQLiteConfig.setup).toHaveBeenCalledWith()
        expect(queries.pop()).toBe('CREATE INDEX IF NOT EXISTS ThreadListIndex ON Thread(last_message_timestamp DESC, namespace_id, id)')

      it "should not fail if additional config is present, but setup is undefined", ->
        delete TestModel.additionalSQLiteConfig['setup']
        @m = new TestModel(id: 'local-6806434c-b0cd', body: 'hello world')
        expect( => @connection._setupQueriesForTable(TestModel)).not.toThrow()

