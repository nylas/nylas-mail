DatabaseStore = require '../../src/flux/stores/database-store'

QueryRange = require '../../src/flux/models/query-range'
MutableQueryResultSet = require '../../src/flux/models/mutable-query-result-set'
QuerySubscription = require '../../src/flux/models/query-subscription'
Thread = require '../../src/flux/models/thread'
Label = require '../../src/flux/models/label'
Utils = require '../../src/flux/models/utils'

describe "QuerySubscription", ->
  describe "constructor", ->
    describe "when a query is provided", ->
      it "should finalize the query", ->
        query = DatabaseStore.findAll(Thread)
        subscription = new QuerySubscription(query)
        expect(query._finalized).toBe(true)

      it "should throw an exception if the query is a count query, which cannot be observed", ->
        query = DatabaseStore.count(Thread)
        expect =>
          subscription = new QuerySubscription(query)
        .toThrow()

      it "should call `update` to initialize the result set", ->
        query = DatabaseStore.findAll(Thread)
        spyOn(QuerySubscription.prototype, 'update')
        subscription = new QuerySubscription(query)
        expect(QuerySubscription.prototype.update).toHaveBeenCalled()

      describe "when initialModels are provided", ->
        it "should apply the models and trigger", ->
          query = DatabaseStore.findAll(Thread)
          threads = [1..5].map (i) -> new Thread(id: i)
          subscription = new QuerySubscription(query, {initialModels: threads})
          expect(subscription._set).not.toBe(null)

  describe "query", ->
    it "should return the query", ->
      query = DatabaseStore.findAll(Thread)
      subscription = new QuerySubscription(query)
      expect(subscription.query()).toBe(query)

  describe "addCallback", ->
    it "should emit the last result to the new callback if one is available", ->
      cb = jasmine.createSpy('callback')
      runs =>
        subscription = new QuerySubscription(DatabaseStore.findAll(Thread))
        subscription._lastResult = 'something'
        subscription.addCallback(cb)
      waitsFor =>
        cb.callCount > 0
      expect =>
        expect(cb).toHaveBeenCalledWith('something')

  describe "applyChangeRecord", ->
    spyOn(Utils, 'generateTempId').andCallFake => undefined

    scenarios = [{
      name: "query with full set of objects (4)"
      query: DatabaseStore.findAll(Thread)
                          .where(Thread.attributes.accountId.equal('a'))
                          .limit(4)
                          .offset(2)
      lastModels: [
        new Thread(accountId: 'a', clientId: '4', lastMessageReceivedTimestamp: 4)
        new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
        new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
        new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1),
      ]
      tests: [{
        name: 'Item in set saved - new serverId, same sort value'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', serverId: 's-4', clientId: '4', lastMessageReceivedTimestamp: 4, subject: 'hello')]
          type: 'persist'
        nextModels:[
          new Thread(accountId: 'a', serverId: 's-4', clientId: '4', lastMessageReceivedTimestamp: 4, subject: 'hello')
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
          new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1),
        ]
        mustUpdate: false
        mustTrigger: true
        mustRefetchAllIds: false
      },{
        name: 'Item in set saved - new sort value'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '5', lastMessageReceivedTimestamp: 3.5)]
          type: 'persist'
        nextModels:[
          new Thread(accountId: 'a', clientId: '4', lastMessageReceivedTimestamp: 4),
          new Thread(accountId: 'a', clientId: '5', lastMessageReceivedTimestamp: 3.5),
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
        ]
        mustUpdate: false
        mustTrigger: true
        mustRefetchAllIds: true
      },{
        name: 'Item saved - does not match query clauses, offset > 0'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'b', clientId: '5', lastMessageReceivedTimestamp: 5)]
          type: 'persist'
        nextModels: 'unchanged'
        mustUpdate: true
        mustRefetchAllIds: true
      },{
        name: 'Item saved - matches query clauses'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '5', lastMessageReceivedTimestamp: -2)]
          type: 'persist'
        mustUpdate: true
        mustRefetchAllIds: true
      },{
        name: 'Item in set saved - no longer matches query clauses'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'b', clientId: '4', lastMessageReceivedTimestamp: 4)]
          type: 'persist'
        nextModels: [
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
          new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1),
        ]
        mustUpdate: true
        mustRefetchAllIds: false
      },{
        name: 'Item in set deleted'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '4')]
          type: 'unpersist'
        nextModels: [
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
          new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1),
        ]
        mustUpdate: true
        mustRefetchAllIds: false
      },{
        name: 'Item not in set deleted'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '5')]
          type: 'unpersist'
        nextModels: 'unchanged'
        mustUpdate: false
        mustRefetchAllIds: false
      }]

    },{
      name: "query with multiple sort orders"
      query: DatabaseStore.findAll(Thread)
                          .where(Thread.attributes.accountId.equal('a'))
                          .limit(4)
                          .offset(2)
                          .order([
                            Thread.attributes.lastMessageReceivedTimestamp.ascending(),
                            Thread.attributes.unread.descending()
                          ])
      lastModels: [
        new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1, unread: true)
        new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 1, unread: false)
        new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 1, unread: false)
        new Thread(accountId: 'a', clientId: '4', lastMessageReceivedTimestamp: 2, unread: true)
      ]
      tests: [{
        name: 'Item in set saved, secondary sort order changed'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 1, unread: true)]
          type: 'persist'
        mustUpdate: true
        mustRefetchAllIds: true
      }]
    }]

    jasmine.unspy(Utils, 'generateTempId')

    describe "scenarios", ->
      scenarios.forEach (scenario) =>
        scenario.tests.forEach (test) =>
          it "with #{scenario.name}, should correctly apply #{test.name}", ->
            subscription = new QuerySubscription(scenario.query)
            subscription._set = new MutableQueryResultSet()
            subscription._set.addModelsInRange(scenario.lastModels, new QueryRange(start: 0, end: scenario.lastModels.length))

            spyOn(subscription, 'update')
            spyOn(subscription, '_createResultAndTrigger')
            subscription._updateInFlight = false
            subscription.applyChangeRecord(test.change)

            if test.mustRefetchAllIds
              expect(subscription._set).toBe(null)
            else if test.nextModels is 'unchanged'
              expect(subscription._set.models()).toEqual(scenario.lastModels)
            else
              expect(subscription._set.models()).toEqual(test.nextModels)

            if test.mustUpdate
              expect(subscription.update).toHaveBeenCalled()

            if test.mustTriger
              expect(subscription._createResultAndTrigger).toHaveBeenCalled()

  describe "update", ->
    beforeEach ->
      spyOn(QuerySubscription.prototype, '_fetchRange').andCallFake ->
        @_set ?= new MutableQueryResultSet()
        Promise.resolve()

    describe "when the query has an infinite range", ->
      it "should call _fetchRange for the entire range", ->
        subscription = new QuerySubscription(DatabaseStore.findAll(Thread))
        subscription.update()
        advanceClock()
        expect(subscription._fetchRange).toHaveBeenCalledWith(QueryRange.infinite(), {entireModels: true})

      it "should fetch full full models only when the previous set is empty", ->
        subscription = new QuerySubscription(DatabaseStore.findAll(Thread))
        subscription._set = new MutableQueryResultSet()
        subscription._set.addModelsInRange([new Thread()], new QueryRange(start: 0, end: 1))
        subscription.update()
        advanceClock()
        expect(subscription._fetchRange).toHaveBeenCalledWith(QueryRange.infinite(), {entireModels: false})

    describe "when the query has a range", ->
      beforeEach ->
        @query = DatabaseStore.findAll(Thread).limit(10)

      describe "when we have no current range", ->
        it "should call _fetchRange for the entire range and fetch full models", ->
          subscription = new QuerySubscription(@query)
          subscription._set = null
          subscription.update()
          advanceClock()
          expect(subscription._fetchRange).toHaveBeenCalledWith(@query.range(), {entireModels: true})

      describe "when we have a previous range", ->
        it "should call _fetchRange for the ranges representing the difference", ->
          customRange1 = jasmine.createSpy('customRange1')
          customRange2 = jasmine.createSpy('customRange2')
          spyOn(QueryRange, 'rangesBySubtracting').andReturn [customRange1, customRange2]

          subscription = new QuerySubscription(@query)
          subscription._set = new MutableQueryResultSet()
          subscription._set.addModelsInRange([new Thread()], new QueryRange(start: 0, end: 1))

          advanceClock()
          subscription._fetchRange.reset()
          subscription._updateInFlight = false
          subscription.update()
          advanceClock()
          expect(subscription._fetchRange.callCount).toBe(2)
          expect(subscription._fetchRange.calls[0].args).toEqual([customRange1, {entireModels: true}])
          expect(subscription._fetchRange.calls[1].args).toEqual([customRange2, {entireModels: true}])
