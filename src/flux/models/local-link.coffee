_ = require 'underscore'
Model = require './model'
Attributes = require '../attributes'

class LocalLink extends Model
  @attributes:
    'id': Attributes.String
      queryable: true
      modelKey: 'id'

    'objectId': Attributes.String
      queryable: true
      modelKey: 'objectId'
  
  constructor: ({@id, @objectId} = {}) ->
    @

module.exports = LocalLink
