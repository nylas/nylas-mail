Matcher = require './attributes/matcher'
SortOrder = require './attributes/sort-order'
Attribute = require './attributes/attribute'
AttributeNumber = require './attributes/attribute-number'
AttributeString = require './attributes/attribute-string'
AttributeObject = require './attributes/attribute-object'
AttributeBoolean = require './attributes/attribute-boolean'
AttributeDateTime = require './attributes/attribute-datetime'
AttributeCollection = require './attributes/attribute-collection'
AttributeJoinedData = require './attributes/attribute-joined-data'

module.exports =
  Matcher: Matcher
  SortOrder: SortOrder

  Number: -> new AttributeNumber(arguments...)
  String: -> new AttributeString(arguments...)
  Object: -> new AttributeObject(arguments...)
  Boolean: -> new AttributeBoolean(arguments...)
  DateTime: -> new AttributeDateTime(arguments...)
  Collection: -> new AttributeCollection(arguments...)
  JoinedData: -> new AttributeJoinedData(arguments...)

  AttributeNumber: AttributeNumber
  AttributeString: AttributeString
  AttributeObject: AttributeObject
  AttributeBoolean: AttributeBoolean
  AttributeDateTime: AttributeDateTime
  AttributeCollection: AttributeCollection
  AttributeJoinedData: AttributeJoinedData
