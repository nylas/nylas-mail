_ = require 'underscore'
Task = require './task'
Actions = require '../actions'
Metadata = require '../models/metadata'
EdgehillAPI = require '../edgehill-api'
DatabaseStore = require '../stores/database-store'
NamespaceStore = require '../stores/namespace-store'

module.exports =
class DestroyMetadataTask extends Task
  constructor: ({@type, @publicId, @key}) ->
    super
    @name = "DestroyMetadataTask"

  shouldDequeueOtherTask: (other) ->
    @_isSameTask(other) or @_isOldCreateTask(other)

  _isSameTask: (other) ->
    other instanceof DestroyMetadataTask and
    @type is other.type and @publicId is other.publicId and @key is other.key

  _isOldCreateTask: (other) ->
    other.name is "CreateMetadataTask"
    @type is other.type and @publicId is other.publicId and @key is other.key

  performLocal: ->
    return Promise.reject(new Error("Must pass a type")) unless @type?
    return Promise.reject(new Error("Must pass an publicId")) unless @publicId?
    new Promise (resolve, reject) =>
      if @key?
        matcher = {@type, @publicId, @key}
      else
        matcher = {@type, @publicId}

      DatabaseStore.findAll(Metadata, matcher)
      .then (models) ->
        if (models ? []).length is 0
          resolve()
        else
          Promise.settle(models.map (m) -> DatabaseStore.unpersistModel(m))
          .then(resolve).catch(reject)
      .catch (error) ->
        console.error "Error finding Metadata to destroy", error
        console.error error.stack
        reject(error)

  performRemote: -> new Promise (resolve, reject) =>
    if @key?
      body = {@key}
    else
      body = null

    EdgehillAPI.request
      method: "DELETE"
      path: "/metadata/#{NamespaceStore.current().id}/#{@type}/#{@publicId}"
      body: body
      success: (args...) =>
        Actions.metadataDestroyed(@type)
        resolve(args...)
      error: (apiError) ->
        apiError.notifyConsole()
        reject(apiError)

  onAPIError: (apiError) ->
    Actions.metadataError _.extend @_baseErrorData(),
      errorType: "APIError"
      error: apiError
    Promise.resolve()

  onOtherError: (otherError) ->
    Actions.metadataError _.extend @_baseErrorData(),
      errorType: "OtherError"
      error: otherError
    Promise.resolve()

  onTimeoutError: (timeoutError) ->
    Actions.metadataError _.extend @_baseErrorData(),
      errorType: "TimeoutError"
      error: timeoutError
    Promise.resolve()

  _baseErrorData: ->
    action: "destroy"
    className: @constructor.name
    type: @type
    publicId: @publicId
    key: @key

  onOfflineError: (offlineError) ->
    Promise.resolve()
