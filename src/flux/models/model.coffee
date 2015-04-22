Attributes = require '../attributes'
ModelQuery = require './query'
{isTempId, generateTempId} = require './utils'
_ = require 'underscore-plus'

##
# A base class for API objects that provides abstract support for serialization
# and deserialization, matching by attributes, and ID-based equality.
#
# @namespace Models
#
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

  ##
  # @return {Array<Attribute>} The set of attributes defined on the Model's constructor
  #
  attributes: ->
    @constructor.attributes

  ##
  # @return {Boolean} True if the object has a server-provided ID, false otherwise.
  #
  isSaved: ->
    !isTempId(@id)

  ##
  # Inflates the model object from JSON, using the defined attributes to guide type
  # coercision.
  #
  # @param {Object} json
  # @chainable
  #
  fromJSON: (json) ->
    for key, attr of @attributes()
      @[key] = attr.fromJSON(json[attr.jsonKey]) unless json[attr.jsonKey] is undefined
    @

  ##
  # Deflates the model to a plain JSON object. Only attributes defined on the model are
  # included in the JSON.
  #
  # @param {Object} options To include joined data attributes in the toJSON representation,
  # pass the `joined` option.
  #
  # @return {Object} JSON object
  #
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

  ##
  # @param {Array<Matcher>} criteria Set of matchers to run on the model.
  # @return {Boolean} True, if the model matches the criteria.
  #
  matches: (criteria) ->
    return false unless criteria instanceof Array
    for matcher in criteria
      return false unless matcher.evaluate(@)
    true


module.exports = Model
