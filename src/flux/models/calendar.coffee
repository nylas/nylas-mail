Model = require './model'
Attributes = require '../attributes'
_ = require 'underscore-plus'

class Calendar extends Model

  @attributes: _.extend {}, Model.attributes,
    'name': Attributes.String
      modelKey: 'name'
    'description': Attributes.String
      modelKey: 'description'
    
module.exports = Calendar