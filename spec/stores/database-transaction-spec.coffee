_ = require 'underscore'

Category = require '../../src/flux/models/category'
Thread = require '../../src/flux/models/thread'
TestModel = require '../fixtures/db-test-model'
ModelQuery = require '../../src/flux/models/query'
DatabaseTransaction = require '../../src/flux/stores/database-transaction'

testMatchers = {'id': 'b'}
testModelInstance = new TestModel(id: "1234")
testModelInstanceA = new TestModel(id: "AAA")
testModelInstanceB = new TestModel(id: "BBB")

describe "DatabaseTransaction", ->
  beforeEach ->
    @databaseMutationHooks = []
    @performed = []
    @database =
      _query: jasmine.createSpy('database._query').andCallFake (query, values=[], options={}) =>
        @performed.push({query, values})
        Promise.resolve([])
      accumulateAndTrigger: jasmine.createSpy('database.accumulateAndTrigger')
      mutationHooks: => @databaseMutationHooks

    @transaction = new DatabaseTransaction(@database)

  describe "execute", ->

  describe "persistModel", ->
    it "should throw an exception if the model is not a subclass of Model", ->
      expect(=> @transaction.persistModel({id: 'asd', subject: 'bla'})).toThrow()

    it "should call through to persistModels", ->
      spyOn(@transaction, 'persistModels').andReturn Promise.resolve()
      @transaction.persistModel(testModelInstance)
      advanceClock()
      expect(@transaction.persistModels.callCount).toBe(1)

  describe "persistModels", ->
    it "should call accumulateAndTrigger with a change that contains the models", ->
      runs =>
        @transaction.execute (t) =>
          t.persistModels([testModelInstanceA, testModelInstanceB])
      waitsFor =>
        @database.accumulateAndTrigger.callCount > 0
      runs =>
        change = @database.accumulateAndTrigger.mostRecentCall.args[0]
        expect(change).toEqual
          objectClass: TestModel.name,
          objectIds: [testModelInstanceA.id, testModelInstanceB.id]
          objects: [testModelInstanceA, testModelInstanceB]
          type:'persist'

    it "should call through to _writeModels after checking them", ->
      spyOn(@transaction, '_writeModels').andReturn Promise.resolve()
      @transaction.persistModels([testModelInstanceA, testModelInstanceB])
      advanceClock()
      expect(@transaction._writeModels.callCount).toBe(1)

    it "should throw an exception if the models are not the same class,\
        since it cannot be specified by the trigger payload", ->
      expect(=> @transaction.persistModels([testModelInstanceA, new Category()])).toThrow()

    it "should throw an exception if the models are not a subclass of Model", ->
      expect(=> @transaction.persistModels([{id: 'asd', subject: 'bla'}])).toThrow()

    describe "mutationHooks", ->
      beforeEach ->
        @beforeShouldThrow = false
        @beforeShouldReject = false

        @hook =
          beforeDatabaseChange: jasmine.createSpy('beforeDatabaseChange').andCallFake =>
            throw new Error("beforeShouldThrow") if @beforeShouldThrow
            new Promise (resolve, reject) =>
              setTimeout =>
                return resolve(new Error("beforeShouldReject")) if @beforeShouldReject
                resolve("value")
              , 1000
          afterDatabaseChange: jasmine.createSpy('afterDatabaseChange').andCallFake =>
            new Promise (resolve, reject) ->
              setTimeout(( => resolve()), 1000)

        @databaseMutationHooks.push(@hook)

        @writeModelsResolve = null
        spyOn(@transaction, '_writeModels').andCallFake =>
          new Promise (resolve, reject) =>
            @writeModelsResolve = resolve

      it "should run pre-mutation hooks, wait to write models, and then run post-mutation hooks", ->
        @transaction.persistModels([testModelInstanceA, testModelInstanceB])
        advanceClock()
        expect(@hook.beforeDatabaseChange).toHaveBeenCalledWith(
          @transaction._query,
          {
            objects: [testModelInstanceA, testModelInstanceB]
            objectIds: [testModelInstanceA.id, testModelInstanceB.id]
            objectClass: testModelInstanceA.constructor.name
            type: 'persist'
          },
          undefined
        )
        expect(@transaction._writeModels).not.toHaveBeenCalled()
        advanceClock(1100)
        advanceClock()
        expect(@transaction._writeModels).toHaveBeenCalled()
        expect(@hook.afterDatabaseChange).not.toHaveBeenCalled()
        @writeModelsResolve()
        advanceClock()
        advanceClock()
        expect(@hook.afterDatabaseChange).toHaveBeenCalledWith(
          @transaction._query,
          {
            objects: [testModelInstanceA, testModelInstanceB]
            objectIds: [testModelInstanceA.id, testModelInstanceB.id]
            objectClass: testModelInstanceA.constructor.name
            type: 'persist'
          },
          "value"
        )

      it "should carry on if a pre-mutation hook throws", ->
        @beforeShouldThrow = true
        @transaction.persistModels([testModelInstanceA, testModelInstanceB])
        advanceClock(1000)
        expect(@hook.beforeDatabaseChange).toHaveBeenCalled()
        advanceClock()
        advanceClock()
        expect(@transaction._writeModels).toHaveBeenCalled()

      it "should carry on if a pre-mutation hook rejects", ->
        @beforeShouldReject = true
        @transaction.persistModels([testModelInstanceA, testModelInstanceB])
        advanceClock(1000)
        expect(@hook.beforeDatabaseChange).toHaveBeenCalled()
        advanceClock()
        advanceClock()
        expect(@transaction._writeModels).toHaveBeenCalled()

  describe "unpersistModel", ->
    it "should delete the model by id", ->
      waitsForPromise =>
        @transaction.execute =>
          @transaction.unpersistModel(testModelInstance)
        .then =>
          expect(@performed.length).toBe(3)
          expect(@performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION")
          expect(@performed[1].query).toBe("DELETE FROM `TestModel` WHERE `id` = ?")
          expect(@performed[1].values[0]).toBe('1234')
          expect(@performed[2].query).toBe("COMMIT")

    it "should call accumulateAndTrigger with a change that contains the model", ->
      runs =>
        @transaction.execute =>
          @transaction.unpersistModel(testModelInstance)
      waitsFor =>
        @database.accumulateAndTrigger.callCount > 0
      runs =>
        change = @database.accumulateAndTrigger.mostRecentCall.args[0]
        expect(change).toEqual({
          objectClass: TestModel.name,
          objectIds: [testModelInstance.id]
          objects: [testModelInstance],
          type:'unpersist'
        })

    describe "when the model has collection attributes", ->
      it "should delete all of the elements in the join tables", ->
        TestModel.configureWithCollectionAttribute()
        waitsForPromise =>
          @transaction.execute (t) =>
            t.unpersistModel(testModelInstance)
          .then =>
            expect(@performed.length).toBe(4)
            expect(@performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION")
            expect(@performed[2].query).toBe("DELETE FROM `TestModelCategory` WHERE `id` = ?")
            expect(@performed[2].values[0]).toBe('1234')
            expect(@performed[3].query).toBe("COMMIT")

    describe "when the model has joined data attributes", ->
      it "should delete the element in the joined data table", ->
        TestModel.configureWithJoinedDataAttribute()
        waitsForPromise =>
          @transaction.execute (t) =>
            t.unpersistModel(testModelInstance)
          .then =>
            expect(@performed.length).toBe(4)
            expect(@performed[0].query).toBe("BEGIN IMMEDIATE TRANSACTION")
            expect(@performed[2].query).toBe("DELETE FROM `TestModelBody` WHERE `id` = ?")
            expect(@performed[2].values[0]).toBe('1234')
            expect(@performed[3].query).toBe("COMMIT")

  describe "_writeModels", ->
    it "should compose a REPLACE INTO query to save the model", ->
      TestModel.configureWithCollectionAttribute()
      @transaction._writeModels([testModelInstance])
      expect(@performed[0].query).toBe("REPLACE INTO `TestModel` (id,data,client_id,server_id) VALUES (?,?,?,?)")

    it "should save the model JSON into the data column", ->
      @transaction._writeModels([testModelInstance])
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
        @transaction._writeModels([@m])
        expect(@performed[0].query).toBe("REPLACE INTO `TestModel` (id,data,datetime,string-json-key,boolean,number) VALUES (?,?,?,?,?,?)")

      it "should use the JSON-form values of the queryable attributes", ->
        json = @m.toJSON()
        @transaction._writeModels([@m])

        values = @performed[0].values
        expect(values[2]).toEqual(json['datetime'])
        expect(values[3]).toEqual(json['string-json-key'])
        expect(values[4]).toEqual(json['boolean'])
        expect(values[5]).toEqual(json['number'])

    describe "when the model has collection attributes", ->
      beforeEach ->
        TestModel.configureWithCollectionAttribute()
        @m = new TestModel(id: 'local-6806434c-b0cd')
        @m.categories = [new Category(id: 'a'),new Category(id: 'b')]
        @transaction._writeModels([@m])

      it "should delete all association records for the model from join tables", ->
        expect(@performed[1].query).toBe('DELETE FROM `TestModelCategory` WHERE `id` IN (\'local-6806434c-b0cd\')')

      it "should insert new association records into join tables in a single query", ->
        expect(@performed[2].query).toBe('INSERT OR IGNORE INTO `TestModelCategory` (`id`, `value`) VALUES (?,?),(?,?)')
        expect(@performed[2].values).toEqual(['local-6806434c-b0cd', 'a','local-6806434c-b0cd', 'b'])

    describe "model collection attributes query building", ->
      beforeEach ->
        TestModel.configureWithCollectionAttribute()
        @m = new TestModel(id: 'local-6806434c-b0cd')
        @m.categories = []

      it "should page association records into multiple queries correctly", ->
        @m.categories.push(new Category(id: "id-#{i}")) for i in [0..199]
        @transaction._writeModels([@m])

        collectionAttributeQueries = _.filter @performed, (i) ->
          i.query.indexOf('INSERT OR IGNORE INTO `TestModelCategory`') == 0

        expect(collectionAttributeQueries.length).toBe(1)
        expect(collectionAttributeQueries[0].values[399]).toEqual('id-199')

      it "should page association records into multiple queries correctly", ->
        @m.categories.push(new Category(id: "id-#{i}")) for i in [0..200]
        @transaction._writeModels([@m])

        collectionAttributeQueries = _.filter @performed, (i) ->
          i.query.indexOf('INSERT OR IGNORE INTO `TestModelCategory`') == 0

        expect(collectionAttributeQueries.length).toBe(2)
        expect(collectionAttributeQueries[0].values[399]).toEqual('id-199')
        expect(collectionAttributeQueries[1].values[1]).toEqual('id-200')

      it "should page association records into multiple queries correctly", ->
        @m.categories.push(new Category(id: "id-#{i}")) for i in [0..201]
        @transaction._writeModels([@m])

        collectionAttributeQueries = _.filter @performed, (i) ->
          i.query.indexOf('INSERT OR IGNORE INTO `TestModelCategory`') == 0

        expect(collectionAttributeQueries.length).toBe(2)
        expect(collectionAttributeQueries[0].values[399]).toEqual('id-199')
        expect(collectionAttributeQueries[1].values[1]).toEqual('id-200')
        expect(collectionAttributeQueries[1].values[3]).toEqual('id-201')

    describe "when the model has joined data attributes", ->
      beforeEach ->
        TestModel.configureWithJoinedDataAttribute()

      it "should not include the value to the joined attribute in the JSON written to the main model table", ->
        @m = new TestModel(clientId: 'local-6806434c-b0cd', serverId: 'server-1', body: 'hello world')
        @transaction._writeModels([@m])
        expect(@performed[0].values).toEqual(['server-1', '{"client_id":"local-6806434c-b0cd","server_id":"server-1","id":"server-1"}', 'local-6806434c-b0cd', 'server-1'])

      it "should write the value to the joined table if it is defined", ->
        @m = new TestModel(id: 'local-6806434c-b0cd', body: 'hello world')
        @transaction._writeModels([@m])
        expect(@performed[1].query).toBe('REPLACE INTO `TestModelBody` (`id`, `value`) VALUES (?, ?)')
        expect(@performed[1].values).toEqual([@m.id, @m.body])

      it "should not write the value to the joined table if it undefined", ->
        @m = new TestModel(id: 'local-6806434c-b0cd')
        @transaction._writeModels([@m])
        expect(@performed.length).toBe(1)
