Attributes = require '../attributes'
ModelQuery = require './query'
{isTempId, generateTempId} = require './utils'
_ = require 'underscore-plus'

# A base class for API objects that provides abstract support for serialization
# and deserialization, matching by attributes, and ID-based equality.
class Model

  @attributes:
    'id': Attributes.String
      queryable: true
      modelKey: 'id'

    'object': Attributes.String
      modelKey: 'object'

    'namespaceId': Attributes.String
      queryable: true
      modelKey: 'namespaceId'
      jsonKey: 'namespace_id'

  @naturalSortOrder: -> null

  constructor: (values = {}) ->
    for key, definition of @attributes()
      @[key] = values[key] if values[key]?
    @id ||= generateTempId()
    @

  attributes: ->
    @constructor.attributes

  isSaved: ->
    !isTempId(@id)

  fromJSON: (json) ->
    for key, attr of @attributes()
      @[key] = attr.fromJSON(json[attr.jsonKey]) unless json[attr.jsonKey] is undefined
    @

  toJSON: (options = {}) ->
    json = {}
    for key, attr of @attributes()
      value = attr.toJSON(@[key])
      if attr instanceof Attributes.AttributeJoinedData
        if options.joined
          throw new Error("toJSON called with {joined:true} but joined value not loaded.") unless value?
        else
          continue
      json[attr.jsonKey] = value
    json['object'] = @constructor.name.toLowerCase()
    json

  toString: ->
    JSON.stringify(@toJSON())

  matches: (criteria) ->
    return false unless criteria instanceof Array
    for matcher in criteria
      return false unless matcher.evaluate(@)
    true


module.exports = Model
