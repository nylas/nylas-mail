QuerySubscriptionPool = require '../../src/flux/models/query-subscription-pool'
DatabaseStore = require '../../src/flux/stores/database-store'
Label = require '../../src/flux/models/label'

describe "QuerySubscriptionPool", ->
  beforeEach ->
    @query = DatabaseStore.findAll(Label)
    QuerySubscriptionPool._subscriptions = []

  describe "add", ->
    it "should add a new subscription with the callback", ->
      callback = jasmine.createSpy('callback')
      QuerySubscriptionPool.add(@query, {}, callback)
      expect(QuerySubscriptionPool._subscriptions.length).toBe(1)
      subscription = QuerySubscriptionPool._subscriptions[0]
      expect(subscription.hasCallback(callback)).toBe(true)

    it "should yield database changes to the subscription", ->
      callback = jasmine.createSpy('callback')
      QuerySubscriptionPool.add(@query, {}, callback)
      subscription = QuerySubscriptionPool._subscriptions[0]
      spyOn(subscription, 'applyChangeRecord')

      record = {objectType: 'whateves'}
      QuerySubscriptionPool._onChange(record)
      expect(subscription.applyChangeRecord).toHaveBeenCalledWith(record)

    describe "unsubscribe", ->
      it "should return an unsubscribe method", ->
        expect(QuerySubscriptionPool.add(@query, {}, -> ) instanceof Function).toBe(true)

      it "should remove the subscription", ->
        unsub = QuerySubscriptionPool.add(@query, {}, -> )
        expect(QuerySubscriptionPool._subscriptions.length).toBe(1)
        unsub()
        expect(QuerySubscriptionPool._subscriptions.length).toBe(0)
