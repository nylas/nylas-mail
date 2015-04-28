Attributes = require '../attributes'
ModelQuery = require './query'
{isTempId, generateTempId} = require './utils'
_ = require 'underscore-plus'

###
Public: A base class for API objects that provides abstract support for
serialization and deserialization, matching by attributes, and ID-based equality.

## Attributes

`id`: {AttributeString} The ID of the model. Queryable.

`object`: {AttributeString} The model's type. This field is used by the JSON
 deserializer to create an instance of the correct class when inflating the object.

`namespaceId`: {AttributeString} The string Namespace Id this model belongs to.

###
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

  # Public: Returns an {Array} of {Attribute} objects defined on the Model's constructor
  #
  attributes: ->
    @constructor.attributes

  # Public Returns true if the object has a server-provided ID, false otherwise.
  #
  isSaved: ->
    !isTempId(@id)

  ##
  # Public: Inflates the model object from JSON, using the defined attributes to
  # guide type coercision.
  #
  # - `json` A plain Javascript {Object} with the JSON representation of the model.
  #
  # This method is chainable.
  #
  fromJSON: (json) ->
    for key, attr of @attributes()
      @[key] = attr.fromJSON(json[attr.jsonKey]) unless json[attr.jsonKey] is undefined
    @

  # Public: Deflates the model to a plain JSON object. Only attributes defined
  # on the model are included in the JSON.
  #
  # - `options` (optional) An {Object} with additional options. To include joined
  #    data attributes in the toJSON representation, pass the `joined:true`
  #
  # Returns an {Object} with the JSON representation of the model.
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
