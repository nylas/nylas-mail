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
    @_subscriptions = []

  add: (query, options, callback) =>
    @_setup() if @_subscriptions.length is 0

    callback._registrationPoint = @_formatRegistrationPoint((new Error).stack)

    subscription = new QuerySubscription(query, options)
    subscription.addCallback(callback)
    @_subscriptions.push(subscription)

    return =>
      subscription.removeCallback(callback)
      @_subscriptions = _.without(@_subscriptions, subscription)

  printSubscriptions: =>
    @_subscriptions.forEach (sub) ->
      console.log(sub._query.sql())
      console.group()
      sub._callbacks.forEach (callback) ->
        console.log("#{callback._registrationPoint}")
      console.groupEnd()

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

  _setup: =>
    DatabaseStore = require '../stores/database-store'
    DatabaseStore.listen @_onChange

  _onChange: (record) =>
    for subscription in @_subscriptions
      subscription.applyChangeRecord(record)

module.exports = new QuerySubscriptionPool()
