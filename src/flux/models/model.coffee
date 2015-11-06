_ = require 'underscore'
Utils = require './utils'
Attributes = require '../attributes'

###
Public: A base class for API objects that provides abstract support for
serialization and deserialization, matching by attributes, and ID-based equality.

## Attributes

`id`: {AttributeString} The resolved canonical ID of the model used in the
database and generally throughout the app. The id property is a custom
getter that resolves to the serverId first, and then the clientId.

`clientId`: {AttributeString} An ID created at object construction and
persists throughout the lifetime of the object. This is extremely useful
for optimistically creating objects (like drafts and categories) and
having a constant reference to it. In all other cases, use the resolved
`id` field.

`serverId`: {AttributeServerId} The server ID of the model. In most cases,
except optimistic creation, this will also be the canonical id of the
object.

`object`: {AttributeString} The model's type. This field is used by the JSON
 deserializer to create an instance of the correct class when inflating the object.

`accountId`: {AttributeString} The string Account Id this model belongs to.

Section: Models
###
class Model

  Object.defineProperty @prototype, "id",
    enumerable: false
    get: -> @serverId ? @clientId
    set: ->
      throw new Error("You may not directly set the ID of an object. Set either the `clientId` or the `serverId` instead.")

  @attributes:
    # Lookups will go through the custom getter.
    'id': Attributes.String
      queryable: true
      modelKey: 'id'

    'clientId': Attributes.String
      queryable: true
      modelKey: 'clientId'
      jsonKey: 'client_id'

    'serverId': Attributes.ServerId
      modelKey: 'serverId'
      jsonKey: 'server_id'

    'object': Attributes.String
      modelKey: 'object'

    'accountId': Attributes.ServerId
      queryable: true
      modelKey: 'accountId'
      jsonKey: 'account_id'

  @naturalSortOrder: -> null

  constructor: (values = {}) ->
    if values["id"] and Utils.isTempId(values["id"])
      values["clientId"] ?= values["id"]
    else
      values["serverId"] ?= values["id"]

    @constructor.attributesKeys ?= Object.keys(@constructor.attributes)
    for key in @constructor.attributesKeys
      continue if key is 'id'
      continue unless values[key]?
      @[key] = values[key]

    @clientId ?= Utils.generateTempId()
    @

  isSaved: ->
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
    if json["id"] and not Utils.isTempId(json["id"])
      @serverId = json["id"]
    @constructor.attributesKeys ?= Object.keys(@constructor.attributes)
    for key in @constructor.attributesKeys
      continue if key is 'id'
      attr = @constructor.attributes[key]
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
    @constructor.attributesKeys ?= Object.keys(@constructor.attributes)
    for key in @constructor.attributesKeys
      continue if key is 'id'
      attr = @constructor.attributes[key]
      continue if attr instanceof Attributes.AttributeJoinedData and options.joined is false
      json[attr.jsonKey] = attr.toJSON(@[key])
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
