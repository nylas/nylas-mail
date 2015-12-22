DatabaseStore = require '../../src/flux/stores/database-store'
QuerySubscription = require '../../src/flux/models/query-subscription'
Thread = require '../../src/flux/models/thread'
Label = require '../../src/flux/models/label'
Utils = require '../../src/flux/models/utils'

describe "QuerySubscription", ->
  describe "constructor", ->
    it "should throw an error if the query is a count query", ->
      query = DatabaseStore.findAll(Label).count()
      expect( => new QuerySubscription(query)).toThrow()

    it "should throw an error if a query is not provided", ->
      expect( => new QuerySubscription({})).toThrow()

    it "should fetch an initial result set", ->
      spyOn(QuerySubscription.prototype, '_refetchResultSet')
      sub = new QuerySubscription(DatabaseStore.findAll(Label))
      expect(QuerySubscription.prototype._refetchResultSet).toHaveBeenCalled()

  describe "applyChangeRecord", ->
    spyOn(Utils, 'generateTempId').andCallFake => undefined

    scenarios = [{
      name: "query with full set of objects (4)"
      query: DatabaseStore.findAll(Thread)
                          .where(Thread.attributes.accountId.equal('a'))
                          .limit(4)
                          .offset(2)
      lastResultSet: [
        new Thread(accountId: 'a', clientId: '4', lastMessageReceivedTimestamp: 4)
        new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
        new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
        new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1),
      ]
      tests: [{
        name: 'Item saved which belongs in the set'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '5', lastMessageReceivedTimestamp: 3.5)]
          type: 'persist'
        newResultSet:[
          new Thread(accountId: 'a', clientId: '4', lastMessageReceivedTimestamp: 4),
          new Thread(accountId: 'a', clientId: '5', lastMessageReceivedTimestamp: 3.5),
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
        ]
        refetchRequired: false
      },{
        name: 'Item saved which does not match query clauses'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'b', clientId: '5', lastMessageReceivedTimestamp: 5)]
          type: 'persist'
        newResultSet: 'unchanged'
        refetchRequired: false
      },{
        name: 'Item saved which does not lie in the range after sorting'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'b', clientId: '5', lastMessageReceivedTimestamp: -2)]
          type: 'persist'
        newResultSet: 'unchanged'
        refetchRequired: false
      },{
        name: 'Item in set saved'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', serverId: 's-4', clientId: '4', lastMessageReceivedTimestamp: 4, subject: 'hello')]
          type: 'persist'
        newResultSet:[
          new Thread(accountId: 'a', serverId: 's-4', clientId: '4', lastMessageReceivedTimestamp: 4, subject: 'hello')
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
          new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1),
        ]
        refetchRequired: false
      },{
        name: 'Item in set saved, sort order changed (within range only)'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 1.5)]
          type: 'persist'
        newResultSet:[
          new Thread(accountId: 'a', clientId: '4', lastMessageReceivedTimestamp: 4),
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 1.5),
          new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1),
        ]
        refetchRequired: false
      },{
        name: 'Item in set saved, sort order changed and sorted to edge of set (impacting last)'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 6)]
          type: 'persist'
        refetchRequired: true
      },{
        name: 'Item in set saved, sort order changed and sorted to edge of set (impacting first)'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: -1)]
          type: 'persist'
        refetchRequired: true
      },{
        name: 'Item in set saved, no longer matches query clauses'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'b', clientId: '4', lastMessageReceivedTimestamp: 4)]
          type: 'persist'
        newResultSet: [
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
          new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1),
        ]
        refetchRequired: true
      },{
        name: 'Item in set deleted'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '4')]
          type: 'unpersist'
        newResultSet: [
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
          new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1),
        ]
        refetchRequired: true
      },{
        name: 'Item not in set deleted'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '5')]
          type: 'unpersist'
        newResultSet: 'unchanged'
        refetchRequired: false
      }]

    },{
      name: "query with fewer than LIMIT objects"
      query: DatabaseStore.findAll(Thread)
                          .where(Thread.attributes.accountId.equal('a'))
                          .limit(4)
                          .offset(2)
      lastResultSet: [
        new Thread(accountId: 'a', clientId: '4', lastMessageReceivedTimestamp: 4)
        new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
        new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2)
      ]
      tests: [{
        name: 'Item in set saved, no longer matches query clauses'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'b', clientId: '4', lastMessageReceivedTimestamp: 4)]
          type: 'persist'
        newResultSet: [
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
        ]
        refetchRequired: false
      },{
        name: 'Item in set deleted'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '4')]
          type: 'unpersist'
        newResultSet: [
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3),
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2),
        ]
        refetchRequired: false
      }]
    },{
      name: "query with ASC sort order"
      query: DatabaseStore.findAll(Thread)
                          .where(Thread.attributes.accountId.equal('a'))
                          .limit(4)
                          .offset(2)
                          .order(Thread.attributes.lastMessageReceivedTimestamp.ascending())
      lastResultSet: [
        new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1)
        new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2)
        new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 3)
        new Thread(accountId: 'a', clientId: '4', lastMessageReceivedTimestamp: 4)
      ]
      tests: [{
        name: 'Item in set saved, sort order changed'
        change:
          objectClass: Thread.name
          objects: [new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 1.5)]
          type: 'persist'
        newResultSet:[
          new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1)
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 1.5)
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 2)
          new Thread(accountId: 'a', clientId: '4', lastMessageReceivedTimestamp: 4)
        ]
        refetchRequired: false
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
      lastResultSet: [
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
        newResultSet:[
          new Thread(accountId: 'a', clientId: '1', lastMessageReceivedTimestamp: 1, unread: true)
          new Thread(accountId: 'a', clientId: '3', lastMessageReceivedTimestamp: 1, unread: true)
          new Thread(accountId: 'a', clientId: '2', lastMessageReceivedTimestamp: 1, unread: false)
          new Thread(accountId: 'a', clientId: '4', lastMessageReceivedTimestamp: 2, unread: true)
        ]
        refetchRequired: false
      }]
    }]

    jasmine.unspy(Utils, 'generateTempId')

    describe "scenarios", ->
      scenarios.forEach (scenario) =>
        scenario.tests.forEach (test) =>
          it "with #{scenario.name}, should correctly apply #{test.name}", ->
            @q = new QuerySubscription(scenario.query, -> )
            @q._lastResultSet = scenario.lastResultSet
            spyOn(@q, '_invokeCallbacks')
            spyOn(@q, '_refetchResultSet')
            @q.applyChangeRecord(test.change)

            if test.newResultSet is 'unchanged'
              expect(@q._invokeCallbacks).not.toHaveBeenCalled()
              expect(@q._lastResultSet).toEqual(scenario.lastResultSet)

            else if test.newResultSet
              expect(@q._invokeCallbacks).toHaveBeenCalled()
              expect(@q._lastResultSet).toEqual(test.newResultSet)

            if test.refetchRequired
              expect(@q._refetchResultSet).toHaveBeenCalled()
            else
              expect(@q._refetchResultSet).not.toHaveBeenCalled()
