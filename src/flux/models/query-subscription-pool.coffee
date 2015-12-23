_ = require 'underscore'
DatabaseChangeRecord = require '../stores/database-change-record'
QuerySubscription = require './query-subscription'

###
Public: The QuerySubscriptionPool maintains a list of all of the query
subscriptions in the app. In the future, this class will monitor performance,
merge equivalent subscriptions, etc.
###
class QuerySubscriptionPool
  constructor: ->
    @_subscriptions = {}
    @_setup()

  add: (query, options, callback) =>
    callback._registrationPoint = @_formatRegistrationPoint((new Error).stack)

    key = @_keyForQuery(query)
    subscription = @_subscriptions[key]
    if not subscription
      subscription = new QuerySubscription(query, options)
      @_subscriptions[key] = subscription

    subscription.addCallback(callback)
    return =>
      subscription.removeCallback(callback)
      # We could be in the middle of an update that will remove and then re-add
      # the exact same subscription. Keep around the cached set for one tick
      # to see if that happens.
      _.defer => @checkIfSubscriptionNeeded(subscription)

  checkIfSubscriptionNeeded: (subscription) =>
    return unless subscription.callbackCount() is 0
    key = @_keyForQuery(subscription.query())
    delete @_subscriptions[key]

  printSubscriptions: =>
    for key, subscription of @_subscriptions
      console.log(key)
      console.group()
      for callback in subscription._callbacks
        console.log("#{callback._registrationPoint}")
      console.groupEnd()
    return

  _formatRegistrationPoint: (stack) ->
    stack = stack.split('\n')
    ii = 0
    seenRx = false
    while ii < stack.length
      hasRx = stack[ii].indexOf('rx.lite') isnt -1
      seenRx ||= hasRx
      break if seenRx is true and not hasRx
      ii += 1

    return stack[ii..(ii + 4)].join('\n')

  _keyForQuery: (query) =>
    return query.sql()

  _setup: =>
    DatabaseStore = require '../stores/database-store'
    DatabaseStore.listen @_onChange

  _onChange: (record) =>
    for key, subscription of @_subscriptions
      subscription.applyChangeRecord(record)

module.exports = new QuerySubscriptionPool()
