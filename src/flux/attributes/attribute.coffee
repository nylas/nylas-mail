_ = require 'underscore-plus'
Matcher = require './matcher'
SortOrder = require './sort-order'

###
Public: The Attribute class represents a single model attribute, like 'namespace_id'.
Subclasses of {Attribute} like {AttributeDateTime} know how to covert between
the JSON representation of that type and the javascript representation.
The Attribute class also exposes convenience methods for generating {Matcher} objects.

Section: Database
###
class Attribute
  constructor: ({modelKey, queryable, jsonKey}) ->
    @modelKey = modelKey
    @jsonKey = jsonKey || modelKey
    @queryable = queryable
    @

  # Public: Returns a {Matcher} for objects `=` to the provided value.
  equal: (val) ->
    throw (new Error "this field cannot be queried against.") unless @queryable
    new Matcher(@, '=', val)

  # Public: Returns a {Matcher} for objects `!=` to the provided value.
  not: (val) ->
    throw (new Error "this field cannot be queried against.") unless @queryable
    new Matcher(@, '!=', val)

  # Public: Returns a descending {SortOrder} for this attribute.
  descending: ->
    new SortOrder(@, 'DESC')

  # Public: Returns an ascending {SortOrder} for this attribute.
  ascending: ->
    new SortOrder(@, 'ASC')
  toJSON: (val) -> val
  fromJSON: (val) -> val ? null


module.exports = Attribute
