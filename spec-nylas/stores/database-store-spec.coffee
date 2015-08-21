_ = require 'underscore'
ipc = require 'ipc'

Label = require '../../src/flux/models/label'
TestModel = require '../fixtures/db-test-model'
ModelQuery = require '../../src/flux/models/query'
DatabaseStore = require '../../src/flux/stores/database-store'

testMatchers = {'id': 'b'}
testModelInstance = new TestModel(id: '1234')
testModelInstanceA = new TestModel(id: 'AAA')
testModelInstanceB = new TestModel(id: 'BBB')

describe "DatabaseStore", ->
  beforeEach ->
    TestModel.configureBasic()
    spyOn(ModelQuery.prototype, 'where').andCallThrough()
    spyOn(DatabaseStore, '_triggerSoon').andCallFake -> Promise.resolve()

    @performed = []

    # Note: We spy on _query and test all of the convenience methods that sit above
    # it. None of these tests evaluate whether _query works!
    spyOn(DatabaseStore, "_query").andCallFake (query, values=[], options={}) =>
      @performed.push({query: query, values: values})
      return Promise.resolve([])

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
      waitsForPromise ->
        DatabaseStore.persistModel(testModelInstance).then ->
          expect(DatabaseStore._triggerSoon).toHaveBeenCalled()

          change = DatabaseStore._triggerSoon.mostRecentCall.args[0]
          expect(change).toEqual({objectClass: TestModel.name, objects: [testModelInstance], type:'persist'})
        .catch (err) ->
          console.log err

    it "should call through to _writeModels", ->
      spyOn(DatabaseStore, '_writeModels')
      DatabaseStore.persistModel(testModelInstance)
      expect(DatabaseStore._writeModels.callCount).toBe(1)

  describe "persistModels", ->
    it "should cause the DatabaseStore to trigger with a change that contains the models", ->
      waitsForPromise ->
        DatabaseStore.persistModels([testModelInstanceA, testModelInstanceB]).then ->
          expect(DatabaseStore._triggerSoon).toHaveBeenCalled()

          change = DatabaseStore._triggerSoon.mostRecentCall.args[0]
          expect(change).toEqual
            objectClass: TestModel.name,
            objects: [testModelInstanceA, testModelInstanceB]
            type:'persist'

    it "should call through to _writeModels after checking them", ->
      spyOn(DatabaseStore, '_writeModels')
      DatabaseStore.persistModels([testModelInstanceA, testModelInstanceB])
      expect(DatabaseStore._writeModels.callCount).toBe(1)

    it "should throw an exception if the models are not the same class,\
        since it cannot be specified by the trigger payload", ->
      expect(-> DatabaseStore.persistModels([testModelInstanceA, new Label()])).toThrow()

  describe "unpersistModel", ->
    it "should delete the model by Id", -> waitsForPromise =>
      DatabaseStore.unpersistModel(testModelInstance).then =>
        expect(@performed.length).toBe(3)
        expect(@performed[1].query).toBe("DELETE FROM `TestModel` WHERE `id` = ?")
        expect(@performed[1].values[0]).toBe('1234')

    it "should cause the DatabaseStore to trigger() with a change that contains the model", ->
      waitsForPromise ->
        DatabaseStore.unpersistModel(testModelInstance).then ->
          expect(DatabaseStore._triggerSoon).toHaveBeenCalled()

          change = DatabaseStore._triggerSoon.mostRecentCall.args[0]
          expect(change).toEqual({objectClass: TestModel.name, objects: [testModelInstance], type:'unpersist'})

    describe "when the model provides additional sqlite config", ->
      beforeEach ->
        TestModel.configureWithAdditionalSQLiteConfig()

      it "should call the deleteModel method and provide the model", ->
        waitsForPromise ->
          DatabaseStore.unpersistModel(testModelInstance).then ->
            expect(TestModel.additionalSQLiteConfig.deleteModel).toHaveBeenCalled()
            expect(TestModel.additionalSQLiteConfig.deleteModel.mostRecentCall.args[0]).toBe(testModelInstance)

      it "should not fail if additional config is present, but deleteModel is not defined", ->
        delete TestModel.additionalSQLiteConfig['deleteModel']
        expect( => DatabaseStore.unpersistModel(testModelInstance)).not.toThrow()

    describe "when the model has collection attributes", ->
      it "should delete all of the elements in the join tables", ->
        TestModel.configureWithCollectionAttribute()
        waitsForPromise =>
          DatabaseStore.unpersistModel(testModelInstance).then =>
            expect(@performed.length).toBe(4)
            expect(@performed[2].query).toBe("DELETE FROM `TestModel-Label` WHERE `id` = ?")
            expect(@performed[2].values[0]).toBe('1234')

    describe "when the model has joined data attributes", ->
      it "should delete the element in the joined data table", ->
        TestModel.configureWithJoinedDataAttribute()
        waitsForPromise =>
          DatabaseStore.unpersistModel(testModelInstance).then =>
            expect(@performed.length).toBe(4)
            expect(@performed[2].query).toBe("DELETE FROM `TestModelBody` WHERE `id` = ?")
            expect(@performed[2].values[0]).toBe('1234')

  describe "_writeModels", ->
    it "should compose a REPLACE INTO query to save the model", ->
      TestModel.configureWithCollectionAttribute()
      DatabaseStore._writeModels([testModelInstance])
      expect(@performed[0].query).toBe("REPLACE INTO `TestModel` (id,data) VALUES (?,?)")

    it "should save the model JSON into the data column", ->
      DatabaseStore._writeModels([testModelInstance])
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
        DatabaseStore._writeModels([@m])
        expect(@performed[0].query).toBe("REPLACE INTO `TestModel` (id,data,datetime,string-json-key,boolean,number) VALUES (?,?,?,?,?,?)")

      it "should use the JSON-form values of the queryable attributes", ->
        json = @m.toJSON()
        DatabaseStore._writeModels([@m])

        values = @performed[0].values
        expect(values[2]).toEqual(json['datetime'])
        expect(values[3]).toEqual(json['string-json-key'])
        expect(values[4]).toEqual(json['boolean'])
        expect(values[5]).toEqual(json['number'])

    describe "when the model has collection attributes", ->
      beforeEach ->
        TestModel.configureWithCollectionAttribute()
        @m = new TestModel(id: 'local-6806434c-b0cd')
        @m.labels = [new Label(id: 'a'),new Label(id: 'b')]
        DatabaseStore._writeModels([@m])

      it "should delete all association records for the model from join tables", ->
        expect(@performed[1].query).toBe('DELETE FROM `TestModel-Label` WHERE `id` IN (\'local-6806434c-b0cd\')')

      it "should insert new association records into join tables in a single query", ->
        expect(@performed[2].query).toBe('INSERT OR IGNORE INTO `TestModel-Label` (`id`, `value`) VALUES (?,?),(?,?)')
        expect(@performed[2].values).toEqual(['local-6806434c-b0cd', 'a','local-6806434c-b0cd', 'b'])

    describe "model collection attributes query building", ->
      beforeEach ->
        TestModel.configureWithCollectionAttribute()
        @m = new TestModel(id: 'local-6806434c-b0cd')
        @m.labels = []

      it "should page association records into multiple queries correctly", ->
        @m.labels.push(new Label(id: "id-#{i}")) for i in [0..199]
        DatabaseStore._writeModels([@m])

        collectionAttributeQueries = _.filter @performed, (i) ->
          i.query.indexOf('INSERT OR IGNORE INTO `TestModel-Label`') == 0

        expect(collectionAttributeQueries.length).toBe(1)
        expect(collectionAttributeQueries[0].values[399]).toEqual('id-199')

      it "should page association records into multiple queries correctly", ->
        @m.labels.push(new Label(id: "id-#{i}")) for i in [0..200]
        DatabaseStore._writeModels([@m])

        collectionAttributeQueries = _.filter @performed, (i) ->
          i.query.indexOf('INSERT OR IGNORE INTO `TestModel-Label`') == 0

        expect(collectionAttributeQueries.length).toBe(2)
        expect(collectionAttributeQueries[0].values[399]).toEqual('id-199')
        expect(collectionAttributeQueries[1].values[1]).toEqual('id-200')

      it "should page association records into multiple queries correctly", ->
        @m.labels.push(new Label(id: "id-#{i}")) for i in [0..201]
        DatabaseStore._writeModels([@m])

        collectionAttributeQueries = _.filter @performed, (i) ->
          i.query.indexOf('INSERT OR IGNORE INTO `TestModel-Label`') == 0

        expect(collectionAttributeQueries.length).toBe(2)
        expect(collectionAttributeQueries[0].values[399]).toEqual('id-199')
        expect(collectionAttributeQueries[1].values[1]).toEqual('id-200')
        expect(collectionAttributeQueries[1].values[3]).toEqual('id-201')

    describe "when the model has joined data attributes", ->
      beforeEach ->
        TestModel.configureWithJoinedDataAttribute()

      it "should not include the value to the joined attribute in the JSON written to the main model table", ->
        @m = new TestModel(id: 'local-6806434c-b0cd', body: 'hello world')
        DatabaseStore._writeModels([@m])
        expect(@performed[0].values).toEqual(['local-6806434c-b0cd', '{"id":"local-6806434c-b0cd"}'])

      it "should write the value to the joined table if it is defined", ->
        @m = new TestModel(id: 'local-6806434c-b0cd', body: 'hello world')
        DatabaseStore._writeModels([@m])
        expect(@performed[1].query).toBe('REPLACE INTO `TestModelBody` (`id`, `value`) VALUES (?, ?)')
        expect(@performed[1].values).toEqual([@m.id, @m.body])

      it "should not write the valeu to the joined table if it undefined", ->
        @m = new TestModel(id: 'local-6806434c-b0cd')
        DatabaseStore._writeModels([@m])
        expect(@performed.length).toBe(1)

    describe "when the model provides additional sqlite config", ->
      beforeEach ->
        TestModel.configureWithAdditionalSQLiteConfig()

      it "should call the writeModel method and provide the model", ->
        @m = new TestModel(id: 'local-6806434c-b0cd', body: 'hello world')
        DatabaseStore._writeModels([@m])
        expect(TestModel.additionalSQLiteConfig.writeModel).toHaveBeenCalledWith(@m)

      it "should not fail if additional config is present, but writeModel is not defined", ->
        delete TestModel.additionalSQLiteConfig['writeModel']
        @m = new TestModel(id: 'local-6806434c-b0cd', body: 'hello world')
        expect( => DatabaseStore._writeModels([@m])).not.toThrow()

describe "DatabaseStore::_triggerSoon", ->
