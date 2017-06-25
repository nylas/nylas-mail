_ = require 'underscore'
Utils = require './utils'
Attributes = require('../attributes').default

###
Public: A base class for API objects that provides abstract support for
serialization and deserialization, matching by attributes, and ID-based equality.

## Attributes

`id`: {AttributeString} The resolved canonical ID of the model used in the
database and generally throughout the app. The id property is a custom
getter that resolves to the id first, and then the id.

`object`: {AttributeString} The model's type. This field is used by the JSON
 deserializer to create an instance of the correct class when inflating the object.

`accountId`: {AttributeString} The string Account Id this model belongs to.

Section: Models
###
class Model

  @attributes:
    # Lookups will go through the custom getter.
    'id': Attributes.String
      queryable: true
      modelKey: 'id'

    'object': Attributes.String
      modelKey: 'object'

    'accountId': Attributes.String
      queryable: true
      modelKey: 'accountId'

  @naturalSortOrder: -> null

  constructor: (values = {}) ->
    for key in Object.keys(@constructor.attributes)
      continue unless values[key]?
      @[key] = values[key]

    @id ?= Utils.generateTempId()
    @

  isSavedRemotely: ->
    throw new Error("BG TODO")
    @serverId?

  clone: ->
    (new @constructor).fromJSON(@toJSON())

  # Public: Returns an {Array} of {Attribute} objects defined on the Model's constructor
  #
  attributes: ->
    attrs = _.clone(@constructor.attributes)
    delete attrs["id"]
    return attrs

  ##
  # Public: Inflates the model object from JSON, using the defined attributes to
  # guide type coercision.
  #
  # - `json` A plain Javascript {Object} with the JSON representation of the model.
  #
  # This method is chainable.
  #
  fromJSON: (json) ->
    # Note: The loop in this function has been optimized for the V8 'fast case'
    # https://github.com/petkaantonov/bluebird/wiki/Optimization-killers
    #
    for key in Object.keys(@constructor.attributes)
      attr = @constructor.attributes[key]
      attrValue = json[attr.jsonKey]
      @[key] = attr.fromJSON(attrValue) unless attrValue is undefined
    @

  # Public: Deflates the model to a plain JSON object. Only attributes defined
  # on the model are included in the JSON.
  #
  # - `options` (optional) An {Object} with additional options. To skip joined
  #    data attributes in the toJSON representation, pass the `joined:false`
  #
  # Returns an {Object} with the JSON representation of the model.
  #
  toJSON: (options = {}) ->
    json = {}
    for key in Object.keys(@constructor.attributes)
      continue if key is 'id'
      attr = @constructor.attributes[key]
      attrValue = @[key]
      if attrValue is undefined
        attrValue = attr.defaultValue
      continue if attrValue is undefined
      continue if attr instanceof Attributes.AttributeJoinedData and options.joined is false
      json[attr.jsonKey] = attr.toJSON(attrValue)
    json["id"] = @id
    json

  toString: ->
    JSON.stringify(@toJSON())

  # Public: Evaluates the model against one or more {Matcher} objects.
  #
  # - `criteria` An {Array} of {Matcher}s to run on the model.
  #
  # Returns true if the model matches the criteria.
  #
  matches: (criteria) ->
    return false unless criteria instanceof Array
    for matcher in criteria
      return false unless matcher.evaluate(@)
    true


module.exports = Model
