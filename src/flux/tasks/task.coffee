_ = require 'underscore-plus'

# Tasks represent individual changes to the datastore that
# alter the local cache and need to be synced back to the server.

# Tasks should optimistically modify local models and trigger
# model update actions, and also make API calls which trigger
# further model updates once they're complete.

# Subclasses implement `performLocal` and `performRemote`.
#
# `performLocal` can be called directly by whoever has access to the
# class. It can only be called once. If it is not called directly,
# `performLocal` will be invoked as soon as the task is queued. Since
# performLocal is frequently asynchronous, it is sometimes necessary to
# wait for it to finish.
#
# `performRemote` may be called after a delay, depending on internet
# connectivity and dependency resolution.

# Tasks may be arbitrarily dependent on other tasks. To ensure that
# performRemote is called at the right time, subclasses should implement
# shouldWaitForTask(other). For example, the SendDraft task is dependent
# on the draft's files' UploadFile tasks completing.

# Tasks may also implement shouldCancelUnstartedTask(other). Returning true
# will cause the other event to be removed from the queue. This is useful in
# offline mode especially, when the user might Save,Save,Save,Save,Send.
# Each newly queued Save can cancel the (unstarted) save task in the queue.

# Because tasks may be queued and performed when internet is available,
# they may need to be persisted to disk. Subclasses should implement
# serialize / deserialize to convert to / from raw JSON.

class Task
  constructor: ->
    @retryCount = 0

  # Called if a task is aborted while it is being processed
  abort: ->

  cleanup: ->
    true

  shouldCancelUnstartedTask: (other) ->
    false

  shouldWaitForTask: (other) ->
    false

  shouldRetry: (error) ->
    # Do not retry if this is a non-network error. Subclasses can override
    # shouldRetry to add additional logic here.
    return false unless error.statusCode?

    # Do not retry if the server returned a code indicating successful
    # handling of the request with a bad outcome. Making the request again
    # would not resolve the situation.
    return error.statusCode not in [401,403,404,405,406,409]

  performLocal: ->
    Promise.resolve()

  rollbackLocal: ->
    unless atom.inSpecMode()
      console.log("Rolling back an instance of #{@constructor.name} which has not overridden rollbackLocal. Local cache may be contaminated.")
    true

  performRemote: ->
    Promise.resolve()

  toJSON: ->
    json = _.clone(@)
    json['object'] = @constructor.name
    json

  fromJSON: (json) ->
    for key,val of json
      @[key] = val
    @

module.exports = Task
