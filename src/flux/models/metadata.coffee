_ = require 'underscore'
Model = require './model'
Attributes = require '../attributes'

class Metadata extends Model
  @attributes: _.extend {}, Model.attributes,
    'type': Attributes.String
      queryable: true
      modelKey: 'type'
      jsonKey: 'type'

    'publicId': Attributes.String
      queryable: true
      modelKey: 'publicId'
      jsonKey: 'publicId'

    'key': Attributes.String
      queryable: true
      modelKey: 'key'
      jsonKey: 'key'

    'value': Attributes.Object
      modelKey: 'value'
      jsonKey: 'value'

  Object.defineProperty @prototype, "id",
    enumerable: false
    get: ->
      if @type and @publicid and @key
        return "#{@type}/#{@publicid}/#{@key}"
      else
        return @serverId ? @clientId
    set: ->
      throw new Error("You may not directly set the ID of an object. Set either the `clientId` or the `serverId` instead.")

module.exports = Metadata
