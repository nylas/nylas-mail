QuerySubscriptionPool = require '../../src/flux/models/query-subscription-pool'
DatabaseStore = require '../../src/flux/stores/database-store'
Label = require '../../src/flux/models/label'

describe "QuerySubscriptionPool", ->
  beforeEach ->
    @query = DatabaseStore.findAll(Label)
    @queryKey = @query.sql()
    QuerySubscriptionPool._subscriptions = {}

  describe "add", ->
    it "should add a new subscription with the callback", ->
      callback = jasmine.createSpy('callback')
      QuerySubscriptionPool.add(@query, {}, callback)
      expect(QuerySubscriptionPool._subscriptions[@queryKey]).toBeDefined()

      subscription = QuerySubscriptionPool._subscriptions[@queryKey]
      expect(subscription.hasCallback(callback)).toBe(true)

    it "should yield database changes to the subscription", ->
      callback = jasmine.createSpy('callback')
      QuerySubscriptionPool.add(@query, {}, callback)
      subscription = QuerySubscriptionPool._subscriptions[@queryKey]
      spyOn(subscription, 'applyChangeRecord')

      record = {objectType: 'whateves'}
      QuerySubscriptionPool._onChange(record)
      expect(subscription.applyChangeRecord).toHaveBeenCalledWith(record)

    describe "unsubscribe", ->
      it "should return an unsubscribe method", ->
        expect(QuerySubscriptionPool.add(@query, {}, -> ) instanceof Function).toBe(true)

      it "should remove the callback from the subscription", ->
        cb = ->

        unsub = QuerySubscriptionPool.add(@query, {}, cb)
        subscription = QuerySubscriptionPool._subscriptions[@queryKey]

        expect(subscription.hasCallback(cb)).toBe(true)
        unsub()
        expect(subscription.hasCallback(cb)).toBe(false)

      it "should wait before removing th subscription to make sure it's not reused", ->
        unsub = QuerySubscriptionPool.add(@query, {}, -> )
        expect(QuerySubscriptionPool._subscriptions[@queryKey]).toBeDefined()
        unsub()
        expect(QuerySubscriptionPool._subscriptions[@queryKey]).toBeDefined()
        advanceClock()
        expect(QuerySubscriptionPool._subscriptions[@queryKey]).toBeUndefined()
