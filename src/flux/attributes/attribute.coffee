_ = require 'underscore'
Matcher = require './matcher'
SortOrder = require './sort-order'

###
Public: The Attribute class represents a single model attribute, like 'account_id'.
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
    throw (new Error "Attribute::equal (#{@modelKey}) - you must provide a value") unless val?
    throw (new Error "Attribute::equal (#{@modelKey}) - this field cannot be queried against") unless @queryable
    new Matcher(@, '=', val)

  # Public: Returns a {Matcher} for objects `=` to the provided value.
  in: (val) ->
    throw (new Error "Attribute.in: you must pass an array of values.") unless val instanceof Array
    throw (new Error "Attribute::in (#{@modelKey}) - you must provide a value") unless val?
    throw (new Error "Attribute::in (#{@modelKey}) - this field cannot be queried against") unless @queryable
    new Matcher(@, 'in', val)

  # Public: Returns a {Matcher} for objects `!=` to the provided value.
  not: (val) ->
    throw (new Error "Attribute::not (#{@modelKey}) - you must provide a value") unless val?
    throw (new Error "Attribute::not (#{@modelKey}) - this field cannot be queried against") unless @queryable
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
