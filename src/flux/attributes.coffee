AttributeBoolean = require './attributes/attribute-boolean'
AttributeNumber = require './attributes/attribute-number'
AttributeString = require './attributes/attribute-string'
AttributeDateTime = require './attributes/attribute-datetime'
AttributeCollection = require './attributes/attribute-collection'
AttributeJoinedData = require './attributes/attribute-joined-data'
Attribute = require './attributes/attribute'
Matcher = require './attributes/matcher'
SortOrder = require './attributes/sort-order'

module.exports =
  Number: -> new AttributeNumber(arguments...)
  String: -> new AttributeString(arguments...)
  DateTime: -> new AttributeDateTime(arguments...)
  Collection: -> new AttributeCollection(arguments...)
  Boolean: -> new AttributeBoolean(arguments...)
  Object: -> new Attribute(arguments...)
  JoinedData: -> new AttributeJoinedData(arguments...)

  AttributeNumber: AttributeNumber
  AttributeString: AttributeString
  AttributeDateTime: AttributeDateTime
  AttributeCollection: AttributeCollection
  AttributeBoolean: AttributeBoolean
  AttributeJoinedData: AttributeJoinedData

  SortOrder: SortOrder
  Matcher: Matcher
