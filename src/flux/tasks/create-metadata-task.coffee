_ = require 'underscore'
Task = require './task'
{APIError} = require '../errors'
Actions = require '../actions'
Metadata = require '../models/metadata'
EdgehillAPI = require '../edgehill-api'
DatabaseStore = require '../stores/database-store'
AccountStore = require '../stores/account-store'

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
    DatabaseStore.inTransaction (t) =>
      t.persistModel(@metadatum)

  performRemote: ->
    new Promise (resolve, reject) =>
      EdgehillAPI.request
        method: "POST"
        path: "/metadata/#{AccountStore.current().id}/#{@type}/#{@publicId}"
        body:
          key: @key
          value: @value
        success: =>
          Actions.metadataCreated @type, @metadatum
          resolve(Task.Status.Success)
        error: (apiError) =>
          Actions.metadataError _.extend @_baseErrorData(),
            errorType: "APIError"
            error: apiError
          resolve(Task.Status.Failed)

  _baseErrorData: ->
    action: "create"
    className: @constructor.name
    type: @type
    publicId: @publicId
    key: @key
    value: @value
