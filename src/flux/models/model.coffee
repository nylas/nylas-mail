Attributes = require '../attributes'
ModelQuery = require './query'
{isTempId, generateTempId} = require './utils'
_ = require 'underscore'

###
Public: A base class for API objects that provides abstract support for
serialization and deserialization, matching by attributes, and ID-based equality.

## Attributes

`id`: {AttributeString} The ID of the model. Queryable.

`object`: {AttributeString} The model's type. This field is used by the JSON
 deserializer to create an instance of the correct class when inflating the object.

`accountId`: {AttributeString} The string Namespace Id this model belongs to.

Section: Models
###
class Model

  @attributes:
    'id': Attributes.String
      queryable: true
      modelKey: 'id'

    'object': Attributes.String
      modelKey: 'object'

    'accountId': Attributes.String
      queryable: true
      modelKey: 'accountId'
      jsonKey: 'account_id'

  @naturalSortOrder: -> null

  constructor: (values = {}) ->
    for key, definition of @attributes()
      @[key] = values[key] if values[key]?
    @id ||= generateTempId()
    @

  clone: ->
    (new @constructor).fromJSON(@toJSON())

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
  # - `options` (optional) An {Object} with additional options. To skip joined
  #    data attributes in the toJSON representation, pass the `joined:false`
  #
  # Returns an {Object} with the JSON representation of the model.
  #
  toJSON: (options = {}) ->
    json = {}
    for key, attr of @attributes()
      value = attr.toJSON(@[key])
      if attr instanceof Attributes.AttributeJoinedData and options.joined is false
        continue
      json[attr.jsonKey] = value
    json['object'] = @constructor.name.toLowerCase()
    json['__constructorName'] = @__constructorName
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
