ModelQuery = require '../../src/flux/models/query'
{Matcher} = require '../../src/flux/attributes'
Message = require '../../src/flux/models/message'
Thread = require '../../src/flux/models/thread'
Namespace = require '../../src/flux/models/namespace'

describe "ModelQuery", ->
  beforeEach ->
    @db = {}

  describe "where", ->
    beforeEach ->
      @q = new ModelQuery(Thread, @db)
      @m1 = Thread.attributes.id.equal(4)
      @m2 = Thread.attributes.labels.contains('label-id')

    it "should accept an array of Matcher objects", ->
      @q.where([@m1,@m2])
      expect(@q._matchers.length).toBe(2)
      expect(@q._matchers[0]).toBe(@m1)
      expect(@q._matchers[1]).toBe(@m2)

    it "should accept a single Matcher object", ->
      @q.where(@m1)
      expect(@q._matchers.length).toBe(1)
      expect(@q._matchers[0]).toBe(@m1)

    it "should append to any existing where clauses", ->
      @q.where(@m1)
      @q.where(@m2)
      expect(@q._matchers.length).toBe(2)
      expect(@q._matchers[0]).toBe(@m1)
      expect(@q._matchers[1]).toBe(@m2)

    it "should accept a shorthand format", ->
      @q.where({id: 4, lastMessageReceivedTimestamp: 1234})
      expect(@q._matchers.length).toBe(2)
      expect(@q._matchers[0].attr.modelKey).toBe('id')
      expect(@q._matchers[0].comparator).toBe('=')
      expect(@q._matchers[0].val).toBe(4)

    it "should return the query so it can be chained", ->
      expect(@q.where({id: 4})).toBe(@q)

    it "should immediately raise an exception if an un-queryable attribute is specified", ->
      expect(-> @q.where({snippet: 'My Snippet'})).toThrow()

    it "should immediately raise an exception if a non-existent attribute is specified", ->
      expect(-> @q.where({looksLikeADuck: 'of course'})).toThrow()

  describe "order", ->
    beforeEach ->
      @q = new ModelQuery(Thread, @db)
      @o1 = Thread.attributes.lastMessageReceivedTimestamp.descending()
      @o2 = Thread.attributes.subject.descending()

    it "should accept an array of SortOrders", ->
      @q.order([@o1,@o2])
      expect(@q._orders.length).toBe(2)

    it "should accept a single SortOrder object", ->
      @q.order(@o2)
      expect(@q._orders.length).toBe(1)

    it "should extend any existing ordering", ->
      @q.order(@o1)
      @q.order(@o2)
      expect(@q._orders.length).toBe(2)
      expect(@q._orders[0]).toBe(@o1)
      expect(@q._orders[1]).toBe(@o2)

    it "should return the query so it can be chained", ->
      expect(@q.order(@o2)).toBe(@q)
  
  describe "include", ->
    beforeEach ->
      @q = new ModelQuery(Message, @db)

    it "should throw an exception if the attribute is not a joined data attribute", ->
      expect( =>
        @q.include(Message.attributes.unread)
      ).toThrow()

    it "should add the provided property to the list of joined properties", ->
      expect(@q._includeJoinedData).toEqual([])
      @q.include(Message.attributes.body)
      expect(@q._includeJoinedData).toEqual([Message.attributes.body])

  describe "includeAll", ->
    beforeEach ->
      @q = new ModelQuery(Message, @db)

    it "should add all the JoinedData attributes of the class", ->
      expect(@q._includeJoinedData).toEqual([])
      @q.includeAll()
      expect(@q._includeJoinedData).toEqual([Message.attributes.body])

  describe "formatResult", ->
    it "should always return a Number for counts", ->
      q = new ModelQuery(Message, @db)
      q.where({namespaceId: 'abcd'}).count()
      expect(q.formatResult([["12"]])).toBe(12)

  describe "sql", ->
    beforeEach ->
      @runScenario = (klass, scenario) ->
        q = new ModelQuery(klass, @db)
        Matcher.muid = 1
        scenario.builder(q)
        expect(q.sql().trim()).toBe(scenario.sql.trim())

    it "should correctly generate queries with multiple where clauses", ->
      @runScenario Namespace,
        builder: (q) -> q.where({emailAddress: 'ben@nylas.com'}).where({id: 2})
        sql: "SELECT `Namespace`.`data` FROM `Namespace`  \
              WHERE `Namespace`.`email_address` = 'ben@nylas.com' AND `Namespace`.`id` = 2"

    it "should correctly generate COUNT queries", ->
      @runScenario Thread,
        builder: (q) -> q.where({namespaceId: 'abcd'}).count()
        sql: "SELECT COUNT(*) as count FROM `Thread`  \
              WHERE `Thread`.`namespace_id` = 'abcd'  "

    it "should correctly generate LIMIT 1 queries for single items", ->
      @runScenario Thread,
        builder: (q) -> q.where({namespaceId: 'abcd'}).one()
        sql: "SELECT `Thread`.`data` FROM `Thread`  \
              WHERE `Thread`.`namespace_id` = 'abcd'  \
              ORDER BY `Thread`.`last_message_received_timestamp` DESC LIMIT 1"

    it "should correctly generate `contains` queries using JOINS", ->
      @runScenario Thread,
        builder: (q) -> q.where(Thread.attributes.labels.contains('label-id')).where({id: '1234'})
        sql: "SELECT `Thread`.`data` FROM `Thread` \
              INNER JOIN `Thread-Label` AS `M1` ON `M1`.`id` = `Thread`.`id` \
              WHERE `M1`.`value` = 'label-id' AND `Thread`.`id` = '1234'  \
              ORDER BY `Thread`.`last_message_received_timestamp` DESC"

      @runScenario Thread,
        builder: (q) -> q.where([Thread.attributes.labels.contains('l-1'), Thread.attributes.labels.contains('l-2')])
        sql: "SELECT `Thread`.`data` FROM `Thread` \
              INNER JOIN `Thread-Label` AS `M1` ON `M1`.`id` = `Thread`.`id` \
              INNER JOIN `Thread-Label` AS `M2` ON `M2`.`id` = `Thread`.`id` \
              WHERE `M1`.`value` = 'l-1' AND `M2`.`value` = 'l-2'  \
              ORDER BY `Thread`.`last_message_received_timestamp` DESC"

    it "should correctly generate queries with the class's naturalSortOrder when one is available and no other orders are provided", ->
      @runScenario Thread,
        builder: (q) -> q.where({namespaceId: 'abcd'})
        sql: "SELECT `Thread`.`data` FROM `Thread`  \
              WHERE `Thread`.`namespace_id` = 'abcd'  \
              ORDER BY `Thread`.`last_message_received_timestamp` DESC"

      @runScenario Thread,
        builder: (q) -> q.where({namespaceId: 'abcd'}).order(Thread.attributes.lastMessageReceivedTimestamp.ascending())
        sql: "SELECT `Thread`.`data` FROM `Thread`  \
              WHERE `Thread`.`namespace_id` = 'abcd'  \
              ORDER BY `Thread`.`last_message_received_timestamp` ASC"

      @runScenario Namespace,
        builder: (q) -> q.where({id: 'abcd'})
        sql: "SELECT `Namespace`.`data` FROM `Namespace`  \
              WHERE `Namespace`.`id` = 'abcd'  "

    it "should correctly generate queries requesting joined data attributes", ->
      @runScenario Message,
        builder: (q) -> q.where({id: '1234'}).include(Message.attributes.body)
        sql: "SELECT `Message`.`data`, IFNULL(`MessageBody`.`value`, '!NULLVALUE!') AS `body`  \
              FROM `Message` LEFT OUTER JOIN `MessageBody` ON `MessageBody`.`id` = `Message`.`id` \
              WHERE `Message`.`id` = '1234'  ORDER BY `Message`.`date` ASC"
