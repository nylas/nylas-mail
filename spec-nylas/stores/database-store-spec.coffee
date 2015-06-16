DatabaseStore = require '../../src/flux/stores/database-store'
Model = require '../../src/flux/models/model'
ModelQuery = require '../../src/flux/models/query'
Attributes = require '../../src/flux/attributes'
Tag = require '../../src/flux/models/tag'
_ = require 'underscore'

class TestModel extends Model
  @attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'

TestModel.configureWithAllAttributes = ->
  TestModel.attributes =
    'datetime': Attributes.DateTime
      queryable: true
      modelKey: 'datetime'
    'string': Attributes.String
      queryable: true
      modelKey: 'string'
      jsonKey: 'string-json-key'
    'boolean': Attributes.Boolean
      queryable: true
      modelKey: 'boolean'
    'number': Attributes.Number
      queryable: true
      modelKey: 'number'
    'other': Attributes.String
      modelKey: 'other'

TestModel.configureWithCollectionAttribute = ->
  TestModel.attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'
    'tags': Attributes.Collection
      queryable: true
      modelKey: 'tags'
      itemClass: Tag


TestModel.configureWithJoinedDataAttribute = ->
  TestModel.attributes =
    'id': Attributes.String
      queryable: true
      modelKey: 'id'
    'body': Attributes.JoinedData
      modelTable: 'TestModelBody'
      modelKey: 'body'


testMatchers = {'id': 'b'}
testModelInstance = new TestModel(id: '1234')
testModelInstanceA = new TestModel(id: 'AAA')
testModelInstanceB = new TestModel(id: 'BBB')

describe "DatabaseStore", ->
  beforeEach ->
    spyOn(ModelQuery.prototype, 'where').andCallThrough()
    spyOn(DatabaseStore, 'triggerSoon')

    @performed = []
    @transactionCount = 0

    # Pass spyTx() to functions that take a tx reference to log
    # performed queries to the @performed array.
    @spyTx = ->
      execute: (query, values, success) =>
        @performed.push({query: query, values: values})
        success() if success

    # Spy on the DatabaseStore and return our use spyTx() to generate
    # new transactions instead of using the real websql transaction.
    spyOn(DatabaseStore, 'inTransaction').andCallFake (options, callback) =>
      @transactionCount += 1
      callback(@spyTx())
      Promise.resolve()

  describe "find", ->
    it "should return a ModelQuery for retrieving a single item by Id", ->
      q = DatabaseStore.find(TestModel, "4")
      expect(q.sql()).toBe("SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = '4'  LIMIT 1")

  describe "findBy", ->
    it "should pass the provided predicates on to the ModelQuery", ->
      matchers = {'id': 'b'}
      DatabaseStore.findBy(TestModel, testMatchers)
      expect(ModelQuery.prototype.where).toHaveBeenCalledWith(testMatchers)

    it "should return a ModelQuery ready to be executed", ->
      q = DatabaseStore.findBy(TestModel, testMatchers)
      expect(q.sql()).toBe("SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = 'b'  LIMIT 1")

  describe "findAll", ->
    it "should pass the provided predicates on to the ModelQuery", ->
      DatabaseStore.findAll(TestModel, testMatchers)
      expect(ModelQuery.prototype.where).toHaveBeenCalledWith(testMatchers)

    it "should return a ModelQuery ready to be executed", ->
      q = DatabaseStore.findAll(TestModel, testMatchers)
      expect(q.sql()).toBe("SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = 'b'  ")

  describe "count", ->
    it "should pass the provided predicates on to the ModelQuery", ->
      DatabaseStore.findAll(TestModel, testMatchers)
      expect(ModelQuery.prototype.where).toHaveBeenCalledWith(testMatchers)

    it "should return a ModelQuery configured for COUNT ready to be executed", ->
      q = DatabaseStore.findAll(TestModel, testMatchers)
      expect(q.sql()).toBe("SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = 'b'  ")

  describe "persistModel", ->
    it "should cause the DatabaseStore to trigger with a change that contains the model", ->
      DatabaseStore.persistModel(testModelInstance)
      expect(DatabaseStore.triggerSoon).toHaveBeenCalled()

      change = DatabaseStore.triggerSoon.mostRecentCall.args[0]
      expect(change).toEqual({objectClass: TestModel.name, objects: [testModelInstance], type:'persist'})

    it "should call through to writeModels", ->
      spyOn(DatabaseStore, 'writeModels')
      DatabaseStore.persistModel(testModelInstance)
      expect(DatabaseStore.writeModels.callCount).toBe(1)

  describe "persistModels", ->
    it "should cause the DatabaseStore to trigger with a change that contains the models", ->
      DatabaseStore.persistModels([testModelInstanceA, testModelInstanceB])
      expect(DatabaseStore.triggerSoon).toHaveBeenCalled()

      change = DatabaseStore.triggerSoon.mostRecentCall.args[0]
      expect(change).toEqual
        objectClass: TestModel.name,
        objects: [testModelInstanceA, testModelInstanceB]
        type:'persist'

    it "should call through to writeModels after checking them", ->
      spyOn(DatabaseStore, 'writeModels')
      DatabaseStore.persistModels([testModelInstanceA, testModelInstanceB])
      expect(DatabaseStore.writeModels.callCount).toBe(1)

    it "should only open one database transaction to write all the models", ->
      DatabaseStore.persistModels([testModelInstanceA, testModelInstanceB])
      expect(@transactionCount).toBe(1)

    it "should throw an exception if the models are not the same class,\
        since it cannot be specified by the trigger payload", ->
      expect(-> DatabaseStore.persistModels([testModelInstanceA, new Tag()])).toThrow()

  describe "unpersistModel", ->
    it "should delete the model by Id", ->
      DatabaseStore.unpersistModel(testModelInstance)
      expect(@performed.length).toBe(3)
      expect(@performed[1].query).toBe("DELETE FROM `TestModel` WHERE `id` = ?")
      expect(@performed[1].values[0]).toBe('1234')

    it "should cause the DatabaseStore to trigger() with a change that contains the model", ->
      DatabaseStore.unpersistModel(testModelInstance)
      expect(DatabaseStore.triggerSoon).toHaveBeenCalled()

      change = DatabaseStore.triggerSoon.mostRecentCall.args[0]
      expect(change).toEqual({objectClass: TestModel.name, objects: [testModelInstance], type:'unpersist'})

    describe "when the model has collection attributes", ->
      it "should delete all of the elements in the join tables", ->
        TestModel.configureWithCollectionAttribute()
        DatabaseStore.unpersistModel(testModelInstance)
        expect(@performed.length).toBe(4)
        expect(@performed[2].query).toBe("DELETE FROM `TestModel-Tag` WHERE `id` = ?")
        expect(@performed[2].values[0]).toBe('1234')

    describe "when the model has joined data attributes", ->
      it "should delete the element in the joined data table", ->
        TestModel.configureWithJoinedDataAttribute()
        DatabaseStore.unpersistModel(testModelInstance)
        expect(@performed.length).toBe(4)
        expect(@performed[2].query).toBe("DELETE FROM `TestModelBody` WHERE `id` = ?")
        expect(@performed[2].values[0]).toBe('1234')

  describe "queriesForTableSetup", ->
    it "should return the queries for creating the table and indexes on queryable columns", ->
      TestModel.attributes =
        'attrQueryable': Attributes.DateTime
          queryable: true
          modelKey: 'attrQueryable'
          jsonKey: 'attr_queryable'

        'attrNonQueryable': Attributes.Collection
          modelKey: 'attrNonQueryable'
          jsonKey: 'attr_non_queryable'
      queries = DatabaseStore.queriesForTableSetup(TestModel)
      expected = [
        'CREATE TABLE IF NOT EXISTS `TestModel` (id TEXT PRIMARY KEY,data BLOB,attr_queryable INTEGER)',
        'CREATE INDEX IF NOT EXISTS `TestModel_attr_queryable` ON `TestModel` (`attr_queryable`)',
        'CREATE UNIQUE INDEX IF NOT EXISTS `TestModel_id` ON `TestModel` (`id`)'
      ]
      for query,i in queries
        expect(query).toBe(expected[i])

    it "should correctly create join tables for models that have queryable collections", ->
      TestModel.configureWithCollectionAttribute()
      queries = DatabaseStore.queriesForTableSetup(TestModel)
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
      queries = DatabaseStore.queriesForTableSetup(TestModel)
      expect(queries[0]).toBe('CREATE TABLE IF NOT EXISTS `TestModel` (id TEXT PRIMARY KEY,data BLOB,datetime INTEGER,string-json-key TEXT,boolean INTEGER,number INTEGER)')

  describe "writeModels", ->
    it "should compose a REPLACE INTO query to save the model", ->
      TestModel.configureWithCollectionAttribute()
      DatabaseStore.writeModels(@spyTx(), [testModelInstance])
      expect(@performed[0].query).toBe("REPLACE INTO `TestModel` (id,data) VALUES (?,?)")

    it "should save the model JSON into the data column", ->
      DatabaseStore.writeModels(@spyTx(), [testModelInstance])
      expect(@performed[0].values[1]).toEqual(JSON.stringify(testModelInstance))

    describe "when the model defines additional queryable attributes", ->
      beforeEach ->
        TestModel.configureWithAllAttributes()
        @m = new TestModel
          id: 'local-6806434c-b0cd'
          datetime: new Date()
          string: 'hello world',
          boolean: true,
          number: 15

      it "should populate additional columns defined by the attributes", ->
        DatabaseStore.writeModels(@spyTx(), [@m])
        expect(@performed[0].query).toBe("REPLACE INTO `TestModel` (id,data,datetime,string-json-key,boolean,number) VALUES (?,?,?,?,?,?)")

      it "should use the JSON-form values of the queryable attributes", ->
        json = @m.toJSON()
        DatabaseStore.writeModels(@spyTx(), [@m])

        values = @performed[0].values
        expect(values[2]).toEqual(json['datetime'])
        expect(values[3]).toEqual(json['string-json-key'])
        expect(values[4]).toEqual(json['boolean'])
        expect(values[5]).toEqual(json['number'])

    describe "when the model has collection attributes", ->
      beforeEach ->
        TestModel.configureWithCollectionAttribute()
        @m = new TestModel(id: 'local-6806434c-b0cd')
        @m.tags = [new Tag(id: 'a'),new Tag(id: 'b')]
        DatabaseStore.writeModels(@spyTx(), [@m])

      it "should delete all association records for the model from join tables", ->
        expect(@performed[1].query).toBe('DELETE FROM `TestModel-Tag` WHERE `id` IN (\'local-6806434c-b0cd\')')

      it "should insert new association records into join tables in a single query", ->
        expect(@performed[2].query).toBe('INSERT OR IGNORE INTO `TestModel-Tag` (`id`, `value`) VALUES (?,?),(?,?)')
        expect(@performed[2].values).toEqual(['local-6806434c-b0cd', 'a','local-6806434c-b0cd', 'b'])

    describe "when the model has joined data attributes", ->
      beforeEach ->
        TestModel.configureWithJoinedDataAttribute()

      it "should write the value to the joined table if it is defined", ->
        @m = new TestModel(id: 'local-6806434c-b0cd', body: 'hello world')
        DatabaseStore.writeModels(@spyTx(), [@m])
        expect(@performed[1].query).toBe('REPLACE INTO `TestModelBody` (`id`, `value`) VALUES (?, ?)')
        expect(@performed[1].values).toEqual([@m.id, @m.body])

      it "should not write the valeu to the joined table if it undefined", ->
        @m = new TestModel(id: 'local-6806434c-b0cd')
        DatabaseStore.writeModels(@spyTx(), [@m])
        expect(@performed.length).toBe(1)
