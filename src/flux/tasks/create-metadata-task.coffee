_ = require 'underscore'
Task = require './task'
Actions = require '../actions'
Metadata = require '../models/metadata'
EdgehillAPI = require '../edgehill-api'
DatabaseStore = require '../stores/database-store'
NamespaceStore = require '../stores/namespace-store'

module.exports =
class CreateMetadataTask extends Task
  constructor: ({@type, @publicId, @key, @value}) ->
    super
    @name = "CreateMetadataTask"

  shouldDequeueOtherTask: (other) ->
    @_isSameTask(other) or @_isOldDestroyTask(other)

  _isSameTask: (other) ->
    other instanceof CreateMetadataTask and
    @type is other.type and @publicId is other.publicId and
    @key is other.key and @value is other.value

  _isOldDestroyTask: (other) ->
    other.name is "DestroyMetadataTask"
    @type is other.type and @publicId is other.publicId and @key is other.key

  performLocal: ->
    return Promise.reject(new Error("Must pass a type")) unless @type?
    @metadatum = new Metadata({@type, @publicId, @key, @value})
    return DatabaseStore.persistModel(@metadatum)

  performRemote: -> new Promise (resolve, reject) =>
    EdgehillAPI.request
      method: "POST"
      path: "/metadata/#{NamespaceStore.current().id}/#{@type}/#{@publicId}"
      body:
        key: @key
        value: @value
      success: (args...) =>
        Actions.metadataCreated @type, @metadatum
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
    action: "create"
    className: @constructor.name
    type: @type
    publicId: @publicId
    key: @key
    value: @value

  onOfflineError: (offlineError) ->
    Promise.resolve()
