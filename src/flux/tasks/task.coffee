_ = require 'underscore'
{generateTempId} = require '../models/utils'
Actions = require '../actions'
{APIError,
 OfflineError,
 TimeoutError} = require '../errors'

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

# Tasks may also implement shouldDequeueOtherTask(other). Returning true
# will cause the other event to be removed from the queue. This is useful in
# offline mode especially, when the user might Save,Save,Save,Save,Send.
# Each newly queued Save can cancel the (unstarted) save task in the queue.

# Because tasks may be queued and performed when internet is available,
# they may need to be persisted to disk. Subclasses should implement
# serialize / deserialize to convert to / from raw JSON.

class Task
  ## These are commonly overridden ##
  constructor: ->
    @id = generateTempId()
    @creationDate = new Date()

  performLocal: -> Promise.resolve()

  performRemote: -> Promise.resolve()

  shouldDequeueOtherTask: (other) -> false

  shouldWaitForTask: (other) -> false

  cleanup: -> true

  abort: -> Promise.resolve()

  onAPIError: (apiError) ->
    msg = "We had a problem with the server. Your action was NOT completed."
    Actions.postNotification({message: msg, type: "error"})
    Promise.resolve()

  onOtherError: (otherError) ->
    msg = "Something went wrong. Please report this issue immediately."
    Actions.postNotification({message: msg, type: "error"})
    Promise.resolve()

  onTimeoutError: (timeoutError) ->
    msg = "This took too long. Check your internet connection. Your action was NOT completed."
    Actions.postNotification({message: msg, type: "error"})
    Promise.resolve()

  onOfflineError: (offlineError) ->
    msg = "WARNING: You are offline. This will complete when you come back online."
    Actions.postNotification({message: msg, type: "error"})
    Promise.resolve()

  ## Only override if you know what you're doing ##
  onError: (error) ->
    if error instanceof APIError
      @onAPIError(error)
    else if error instanceof TimeoutError
      @onTimeoutError(error)
    else if error instanceof OfflineError
      @onOfflineError(error)
    else
      if error instanceof Error
        console.error "Task #{@constructor.name} threw an unknown error: #{error.message}"
        console.error error.stack
      @onOtherError(error)

  notifyErrorMessage: (msg) ->
    Actions.postNotification({message: msg, type: "error"})

  toJSON: ->
    json = _.clone(@)
    json['object'] = @constructor.name
    json

  fromJSON: (json) ->
    for key,val of json
      @[key] = val
    @

module.exports = Task
