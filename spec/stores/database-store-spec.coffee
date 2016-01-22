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
    spyOn(DatabaseStore, 'accumulateAndTrigger').andCallFake -> Promise.resolve()

    @performed = []

    # Note: We spy on _query and test all of the convenience methods that sit above
    # it. None of these tests evaluate whether _query works!
    jasmine.unspy(DatabaseStore, "_query")
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

  describe "inTransaction", ->
    it "calls the provided function inside an exclusive transaction", ->
      waitsForPromise =>
        DatabaseStore.inTransaction( =>
          DatabaseStore._query("TEST")
        ).then =>
          expect(@performed.length).toBe 3
          expect(@performed[0].query).toBe "BEGIN IMMEDIATE TRANSACTION"
          expect(@performed[1].query).toBe "TEST"
          expect(@performed[2].query).toBe "COMMIT"

    it "preserves resolved values", ->
      waitsForPromise =>
        DatabaseStore.inTransaction( =>
          DatabaseStore._query("TEST")
          return Promise.resolve("myValue")
        ).then (myValue) =>
          expect(myValue).toBe "myValue"

    it "always fires a COMMIT, even if the body function fails", ->
      waitsForPromise =>
        DatabaseStore.inTransaction( =>
          throw new Error("BOOO")
        ).catch =>
          expect(@performed.length).toBe 2
          expect(@performed[0].query).toBe "BEGIN IMMEDIATE TRANSACTION"
          expect(@performed[1].query).toBe "COMMIT"

    it "can be called multiple times and get queued", ->
      waitsForPromise =>
        Promise.all([
          DatabaseStore.inTransaction( -> )
          DatabaseStore.inTransaction( -> )
          DatabaseStore.inTransaction( -> )
        ]).then =>
          expect(@performed.length).toBe 6
          expect(@performed[0].query).toBe "BEGIN IMMEDIATE TRANSACTION"
          expect(@performed[1].query).toBe "COMMIT"
          expect(@performed[2].query).toBe "BEGIN IMMEDIATE TRANSACTION"
          expect(@performed[3].query).toBe "COMMIT"
          expect(@performed[4].query).toBe "BEGIN IMMEDIATE TRANSACTION"
          expect(@performed[5].query).toBe "COMMIT"

    it "carries on if one of them fails, but still calls the COMMIT for the failed block", ->
      caughtError = false
      DatabaseStore.inTransaction( => DatabaseStore._query("ONE") )
      DatabaseStore.inTransaction( => throw new Error("fail") ).catch ->
        caughtError = true
      DatabaseStore.inTransaction( => DatabaseStore._query("THREE") )
      advanceClock(100)
      expect(@performed.length).toBe 8
      expect(@performed[0].query).toBe "BEGIN IMMEDIATE TRANSACTION"
      expect(@performed[1].query).toBe "ONE"
      expect(@performed[2].query).toBe "COMMIT"
      expect(@performed[3].query).toBe "BEGIN IMMEDIATE TRANSACTION"
      expect(@performed[4].query).toBe "COMMIT"
      expect(@performed[5].query).toBe "BEGIN IMMEDIATE TRANSACTION"
      expect(@performed[6].query).toBe "THREE"
      expect(@performed[7].query).toBe "COMMIT"
      expect(caughtError).toBe true

    it "is actually running in series and blocks on never-finishing specs", ->
      resolver = null
      DatabaseStore.inTransaction( -> )
      advanceClock(100)
      expect(@performed.length).toBe 2
      expect(@performed[0].query).toBe "BEGIN IMMEDIATE TRANSACTION"
      expect(@performed[1].query).toBe "COMMIT"
      DatabaseStore.inTransaction( -> new Promise (resolve, reject) -> resolver = resolve)
      advanceClock(100)
      blockedPromiseDone = false
      DatabaseStore.inTransaction( -> ).then =>
        blockedPromiseDone = true
      advanceClock(100)
      expect(@performed.length).toBe 3
      expect(@performed[2].query).toBe "BEGIN IMMEDIATE TRANSACTION"
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
          DatabaseStore.inTransaction( -> "a" ).then (val) -> v1 = val
          DatabaseStore.inTransaction( -> "b" ).then (val) -> v2 = val
          DatabaseStore.inTransaction( -> "c" ).then (val) -> v3 = val
        ]).then =>
          expect(v1).toBe "a"
          expect(v2).toBe "b"
          expect(v3).toBe "c"

    it "can be called multiple times and get queued", ->
      waitsForPromise =>
        DatabaseStore.inTransaction( -> )
        .then -> DatabaseStore.inTransaction( -> )
        .then -> DatabaseStore.inTransaction( -> )
        .then =>
          expect(@performed.length).toBe 6
          expect(@performed[0].query).toBe "BEGIN IMMEDIATE TRANSACTION"
          expect(@performed[1].query).toBe "COMMIT"
          expect(@performed[2].query).toBe "BEGIN IMMEDIATE TRANSACTION"
          expect(@performed[3].query).toBe "COMMIT"
          expect(@performed[4].query).toBe "BEGIN IMMEDIATE TRANSACTION"
          expect(@performed[5].query).toBe "COMMIT"
