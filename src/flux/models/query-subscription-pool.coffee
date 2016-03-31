_ = require 'underscore'
QuerySubscription = require './query-subscription'

###
Public: The QuerySubscriptionPool maintains a list of all of the query
subscriptions in the app. In the future, this class will monitor performance,
merge equivalent subscriptions, etc.
###
class QuerySubscriptionPool
  constructor: ->
    @_subscriptions = {}
    @_cleanupChecks = []
    @_setup()

  add: (query, callback) =>
    if NylasEnv.inDevMode()
      callback._registrationPoint = @_formatRegistrationPoint((new Error).stack)

    key = @_keyForQuery(query)
    subscription = @_subscriptions[key]
    if not subscription
      subscription = new QuerySubscription(query)
      @_subscriptions[key] = subscription

    subscription.addCallback(callback)
    return =>
      subscription.removeCallback(callback)
      @_scheduleCleanupCheckForSubscription(key)

  addPrivateSubscription: (key, subscription, callback) =>
    @_subscriptions[key] = subscription
    subscription.addCallback(callback)
    return =>
      subscription.removeCallback(callback)
      @_scheduleCleanupCheckForSubscription(key)

  printSubscriptions: =>
    unless NylasEnv.inDevMode()
      return console.log("printSubscriptions is only available in developer mode.")

    for key, subscription of @_subscriptions
      console.log(key)
      console.group()
      for callback in subscription._callbacks
        console.log("#{callback._registrationPoint}")
      console.groupEnd()
    return

  _scheduleCleanupCheckForSubscription: (key) =>
    # We unlisten / relisten to lots of subscriptions and setTimeout is actually
    # /not/ that fast. Create one timeout for all checks, not one for each.
    _.defer(@_runCleanupChecks) if @_cleanupChecks.length is 0
    @_cleanupChecks.push(key)

  _runCleanupChecks: =>
    for key in @_cleanupChecks
      subscription = @_subscriptions[key]
      if subscription and subscription.callbackCount() is 0
        delete @_subscriptions[key]
    @_cleanupChecks = []

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
