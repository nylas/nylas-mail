_ = require 'underscore'

Label = require '../../src/flux/models/label'
Thread = require '../../src/flux/models/thread'
TestModel = require '../fixtures/db-test-model'
ModelQuery = require '../../src/flux/models/query'
DatabaseStore = require '../../src/flux/stores/database-store'

testMatchers = {'id': 'b'}
testModelInstance = new TestModel(id: "1234")
testModelInstanceA = new TestModel(id: "AAA")
testModelInstanceB = new TestModel(id: "BBB")

describe "DatabaseStore", ->
  beforeEach ->
    TestModel.configureBasic()

    DatabaseStore._atomicallyQueue = undefined
    DatabaseStore._mutationQueue = undefined
    DatabaseStore._inTransaction = false

    spyOn(ModelQuery.prototype, 'where').andCallThrough()
    spyOn(DatabaseStore, '_accumulateAndTrigger').andCallFake -> Promise.resolve()

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

  describe "modelify", ->
    beforeEach ->
      @models = [
        new Thread(clientId: 'local-A'),
        new Thread(clientId: 'local-B'),
        new Thread(clientId: 'local-C'),
        new Thread(clientId: 'local-D', serverId: 'SERVER:D'),
        new Thread(clientId: 'local-E', serverId: 'SERVER:E'),
        new Thread(clientId: 'local-F', serverId: 'SERVER:F'),
        new Thread(clientId: 'local-G', serverId: 'SERVER:G')
      ]
      # Actually returns correct sets for queries, since matchers can evaluate
      # themselves against models in memory
      spyOn(DatabaseStore, 'run').andCallFake (query) =>
        results = []
        for model in @models
          found = _.every query._matchers, (matcher) ->
            matcher.evaluate(model)
          results.push(model) if found
        Promise.resolve(results)

    describe "when given an array or input that is not an array", ->
      it "resolves immediately with an empty array", ->
        waitsForPromise =>
          DatabaseStore.modelify(Thread, null).then (output) =>
            expect(output).toEqual([])

    describe "when given an array of mixed IDs, clientIDs, and models", ->
      it "resolves with an array of models", ->
        input = ['SERVER:F', 'local-B', 'local-C', 'SERVER:D', @models[6]]
        expectedOutput = [@models[5], @models[1], @models[2], @models[3], @models[6]]
        waitsForPromise =>
          DatabaseStore.modelify(Thread, input).then (output) =>
            expect(output).toEqual(expectedOutput)

    describe "when the input is only IDs", ->
      it "resolves with an array of models", ->
        input = ['SERVER:D', 'SERVER:F', 'SERVER:G']
        expectedOutput = [@models[3], @models[5], @models[6]]
        waitsForPromise =>
          DatabaseStore.modelify(Thread, input).then (output) =>
            expect(output).toEqual(expectedOutput)

    describe "when the input is only clientIDs", ->
      it "resolves with an array of models", ->
        input = ['local-A', 'local-B', 'local-C', 'local-D']
        expectedOutput = [@models[0], @models[1], @models[2], @models[3]]
        waitsForPromise =>
          DatabaseStore.modelify(Thread, input).then (output) =>
            expect(output).toEqual(expectedOutput)

    describe "when the input is all models", ->
      it "resolves with an array of models", ->
        input = [@models[0], @models[1], @models[2], @models[3]]
        expectedOutput = [@models[0], @models[1], @models[2], @models[3]]
        waitsForPromise =>
          DatabaseStore.modelify(Thread, input).then (output) =>
            expect(output).toEqual(expectedOutput)

  describe "count", ->
    it "should pass the provided predicates on to the ModelQuery", ->
      DatabaseStore.findAll(TestModel, testMatchers)
      expect(ModelQuery.prototype.where).toHaveBeenCalledWith(testMatchers)

    it "should return a ModelQuery configured for COUNT ready to be executed", ->
      q = DatabaseStore.findAll(TestModel, testMatchers)
      expect(q.sql()).toBe("SELECT `TestModel`.`data` FROM `TestModel`  WHERE `TestModel`.`id` = 'b'  ")

  describe "persistModel", ->
    it "should throw an exception if the model is not a subclass of Model", ->
      expect(-> DatabaseStore.persistModel({id: 'asd', subject: 'bla'})).toThrow()

    it "should call through to persistModels", ->
      spyOn(DatabaseStore, 'persistModels').andReturn Promise.resolve()
      DatabaseStore.persistModel(testModelInstance)
      advanceClock()
      expect(DatabaseStore.persistModels.callCount).toBe(1)

  describe "persistModels", ->
    it "should cause the DatabaseStore to trigger with a change that contains the models", ->
      waitsForPromise ->
        DatabaseStore.persistModels([testModelInstanceA, testModelInstanceB]).then ->
          expect(DatabaseStore._accumulateAndTrigger).toHaveBeenCalled()

          change = DatabaseStore._accumulateAndTrigger.mostRecentCall.args[0]
          expect(change).toEqual
            objectClass: TestModel.name,
            objectIds: [testModelInstanceA.id, testModelInstanceB.id]
            objects: [testModelInstanceA, testModelInstanceB]
            type:'persist'

    it "should call through to _writeModels after checking them", ->
      spyOn(DatabaseStore, '_writeModels').andReturn Promise.resolve()
      DatabaseStore.persistModels([testModelInstanceA, testModelInstanceB])
      advanceClock()
      expect(DatabaseStore._writeModels.callCount).toBe(1)

    it "should throw an exception if the models are not the same class,\
        since it cannot be specified by the trigger payload", ->
      expect(-> DatabaseStore.persistModels([testModelInstanceA, new Label()])).toThrow()

    it "should throw an exception if the models are not a subclass of Model", ->
      expect(-> DatabaseStore.persistModels([{id: 'asd', subject: 'bla'}])).toThrow()

    describe "mutationHooks", ->
      beforeEach ->
        @beforeShouldThrow = false
        @beforeShouldReject = false
        @beforeDatabaseChange = jasmine.createSpy('beforeDatabaseChange').andCallFake =>
          throw new Error("beforeShouldThrow") if @beforeShouldThrow
          new Promise (resolve, reject) =>
            setTimeout =>
              return resolve(new Error("beforeShouldReject")) if @beforeShouldReject
              resolve("value")
            , 1000

        @afterDatabaseChange = jasmine.createSpy('afterDatabaseChange').andCallFake =>
          new Promise (resolve, reject) ->
            setTimeout(( => resolve()), 1000)

        @hook = {@beforeDatabaseChange, @afterDatabaseChange}
        DatabaseStore.addMutationHook(@hook)

        @writeModelsResolve = null
        spyOn(DatabaseStore, '_writeModels').andCallFake =>
          new Promise (resolve, reject) =>
            @writeModelsResolve = resolve

      afterEach ->
        DatabaseStore.removeMutationHook(@hook)

      it "should run pre-mutation hooks, wait to write models, and then run post-mutation hooks", ->
        DatabaseStore.persistModels([testModelInstanceA, testModelInstanceB])
        advanceClock()
        expect(@beforeDatabaseChange).toHaveBeenCalledWith(
          DatabaseStore._query,
          {
            objects: [testModelInstanceA, testModelInstanceB]
            objectIds: [testModelInstanceA.id, testModelInstanceB.id]
            objectClass: testModelInstanceA.constructor.name
            type: 'persist'
          },
          undefined
        )
        expect(DatabaseStore._writeModels).not.toHaveBeenCalled()
        advanceClock(1100)
        advanceClock()
        expect(DatabaseStore._writeModels).toHaveBeenCalled()
        expect(@afterDatabaseChange).not.toHaveBeenCalled()
        @writeModelsResolve()
        advanceClock()
        advanceClock()
        expect(@afterDatabaseChange).toHaveBeenCalledWith(
          DatabaseStore._query,
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
        DatabaseStore.persistModels([testModelInstanceA, testModelInstanceB])
        advanceClock()
        expect(@beforeDatabaseChange).toHaveBeenCalled()
        advanceClock()
        advanceClock()
        expect(DatabaseStore._writeModels).toHaveBeenCalled()

      it "should carry on if a pre-mutation hook rejects", ->
        @beforeShouldReject = true
        DatabaseStore.persistModels([testModelInstanceA, testModelInstanceB])
        advanceClock()
        expect(@beforeDatabaseChange).toHaveBeenCalled()
        advanceClock()
        advanceClock()
        expect(DatabaseStore._writeModels).toHaveBeenCalled()

      it "should be atomic: other persistModels calls should not run during the pre+write+post series", ->
        DatabaseStore.persistModels([testModelInstanceA])
        DatabaseStore.persistModels([testModelInstanceB])

        # Expect the entire flow (before, write, after) to be called once
        # before anything is called twice.
        advanceClock()
        advanceClock()
        expect(@beforeDatabaseChange.callCount).toBe(1)
        advanceClock(1100)
        advanceClock()
        expect(DatabaseStore._writeModels.callCount).toBe(1)
        @writeModelsResolve()
        advanceClock(1100)
        advanceClock()
        expect(@afterDatabaseChange.callCount).toBe(1)
        advanceClock()

        # The second call to persistModels can start now
        expect(@beforeDatabaseChange.callCount).toBe(2)

  describe "unpersistModel", ->
    it "should delete the model by id", ->
      waitsForPromise =>
        DatabaseStore.unpersistModel(testModelInstance).then =>
          expect(@performed.length).toBe(3)
          expect(@performed[0].query).toBe("BEGIN EXCLUSIVE TRANSACTION")
          expect(@performed[1].query).toBe("DELETE FROM `TestModel` WHERE `id` = ?")
          expect(@performed[1].values[0]).toBe('1234')
          expect(@performed[2].query).toBe("COMMIT")

    it "should cause the DatabaseStore to trigger() with a change that contains the model", ->
      waitsForPromise ->
        DatabaseStore.unpersistModel(testModelInstance).then ->
          expect(DatabaseStore._accumulateAndTrigger).toHaveBeenCalled()

          change = DatabaseStore._accumulateAndTrigger.mostRecentCall.args[0]
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
          DatabaseStore.unpersistModel(testModelInstance).then =>
            expect(@performed.length).toBe(4)
            expect(@performed[0].query).toBe("BEGIN EXCLUSIVE TRANSACTION")
            expect(@performed[2].query).toBe("DELETE FROM `TestModel-Label` WHERE `id` = ?")
            expect(@performed[2].values[0]).toBe('1234')
            expect(@performed[3].query).toBe("COMMIT")

    describe "when the model has joined data attributes", ->
      it "should delete the element in the joined data table", ->
        TestModel.configureWithJoinedDataAttribute()
        waitsForPromise =>
          DatabaseStore.unpersistModel(testModelInstance).then =>
            expect(@performed.length).toBe(4)
            expect(@performed[0].query).toBe("BEGIN EXCLUSIVE TRANSACTION")
            expect(@performed[2].query).toBe("DELETE FROM `TestModelBody` WHERE `id` = ?")
            expect(@performed[2].values[0]).toBe('1234')
            expect(@performed[3].query).toBe("COMMIT")

  describe "_writeModels", ->
    it "should compose a REPLACE INTO query to save the model", ->
      TestModel.configureWithCollectionAttribute()
      DatabaseStore._writeModels([testModelInstance])
      expect(@performed[0].query).toBe("REPLACE INTO `TestModel` (id,data,client_id,server_id) VALUES (?,?,?,?)")

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
        @m = new TestModel(clientId: 'local-6806434c-b0cd', serverId: 'server-1', body: 'hello world')
        DatabaseStore._writeModels([@m])
        expect(@performed[0].values).toEqual(['server-1', '{"client_id":"local-6806434c-b0cd","server_id":"server-1","id":"server-1"}', 'local-6806434c-b0cd', 'server-1'])

      it "should write the value to the joined table if it is defined", ->
        @m = new TestModel(id: 'local-6806434c-b0cd', body: 'hello world')
        DatabaseStore._writeModels([@m])
        expect(@performed[1].query).toBe('REPLACE INTO `TestModelBody` (`id`, `value`) VALUES (?, ?)')
        expect(@performed[1].values).toEqual([@m.id, @m.body])

      it "should not write the value to the joined table if it undefined", ->
        @m = new TestModel(id: 'local-6806434c-b0cd')
        DatabaseStore._writeModels([@m])
        expect(@performed.length).toBe(1)

  describe "atomically", ->
    it "sets up an exclusive transaction", ->
      waitsForPromise =>
        DatabaseStore.atomically( =>
          DatabaseStore._query("TEST")
        ).then =>
          expect(@performed.length).toBe 3
          expect(@performed[0].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
          expect(@performed[1].query).toBe "TEST"
          expect(@performed[2].query).toBe "COMMIT"

    it "preserves resolved values", ->
      waitsForPromise =>
        DatabaseStore.atomically( =>
          DatabaseStore._query("TEST")
          return Promise.resolve("myValue")
        ).then (myValue) =>
          expect(myValue).toBe "myValue"

    it "always fires a COMMIT, even if the promise fails", ->
      waitsForPromise =>
        DatabaseStore.atomically( =>
          throw new Error("BOOO")
        ).catch =>
          expect(@performed.length).toBe 2
          expect(@performed[0].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
          expect(@performed[1].query).toBe "COMMIT"

    it "can be called multiple times and get queued", ->
      waitsForPromise =>
        Promise.all([
          DatabaseStore.atomically( -> )
          DatabaseStore.atomically( -> )
          DatabaseStore.atomically( -> )
        ]).then =>
          expect(@performed.length).toBe 6
          expect(@performed[0].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
          expect(@performed[1].query).toBe "COMMIT"
          expect(@performed[2].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
          expect(@performed[3].query).toBe "COMMIT"
          expect(@performed[4].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
          expect(@performed[5].query).toBe "COMMIT"

    it "carries on if one of them fails, but still calls the COMMIT for the failed block", ->
      caughtError = false
      DatabaseStore.atomically( => DatabaseStore._query("ONE") )
      DatabaseStore.atomically( => throw new Error("fail") ).catch ->
        caughtError = true
      DatabaseStore.atomically( => DatabaseStore._query("THREE") )
      advanceClock(100)
      expect(@performed.length).toBe 8
      expect(@performed[0].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
      expect(@performed[1].query).toBe "ONE"
      expect(@performed[2].query).toBe "COMMIT"
      expect(@performed[3].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
      expect(@performed[4].query).toBe "COMMIT"
      expect(@performed[5].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
      expect(@performed[6].query).toBe "THREE"
      expect(@performed[7].query).toBe "COMMIT"
      expect(caughtError).toBe true

    it "is actually running in series and blocks on never-finishing specs", ->
      resolver = null
      DatabaseStore.atomically( -> )
      advanceClock(100)
      expect(@performed.length).toBe 2
      expect(@performed[0].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
      expect(@performed[1].query).toBe "COMMIT"
      DatabaseStore.atomically( -> new Promise (resolve, reject) -> resolver = resolve)
      advanceClock(100)
      blockedPromiseDone = false
      DatabaseStore.atomically( -> ).then =>
        blockedPromiseDone = true
      advanceClock(100)
      expect(@performed.length).toBe 3
      expect(@performed[2].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
      expect(blockedPromiseDone).toBe false

      # Now that we've made our assertion about blocking, we need to clean up
      # our test and actually resolve that blocked promise now, otherwise
      # remaining tests won't run properly.
      advanceClock(100)
      resolver()
      advanceClock(100)
      expect(blockedPromiseDone).toBe true
      advanceClock(100)

    it "can be called multiple times and preserve return values", ->
      waitsForPromise =>
        v1 = null
        v2 = null
        v3 = null
        Promise.all([
          DatabaseStore.atomically( -> "a" ).then (val) -> v1 = val
          DatabaseStore.atomically( -> "b" ).then (val) -> v2 = val
          DatabaseStore.atomically( -> "c" ).then (val) -> v3 = val
        ]).then =>
          expect(v1).toBe "a"
          expect(v2).toBe "b"
          expect(v3).toBe "c"

    it "can be called multiple times and get queued", ->
      waitsForPromise =>
        DatabaseStore.atomically( -> )
        .then -> DatabaseStore.atomically( -> )
        .then -> DatabaseStore.atomically( -> )
        .then =>
          expect(@performed.length).toBe 6
          expect(@performed[0].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
          expect(@performed[1].query).toBe "COMMIT"
          expect(@performed[2].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
          expect(@performed[3].query).toBe "COMMIT"
          expect(@performed[4].query).toBe "BEGIN EXCLUSIVE TRANSACTION"
          expect(@performed[5].query).toBe "COMMIT"

describe "DatabaseStore::_accumulateAndTrigger", ->
