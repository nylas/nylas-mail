Model = require './model'
Attributes = require '../attributes'
_ = require 'underscore-plus'

class Tag extends Model

  @attributes: _.extend {}, Model.attributes,
    'name': Attributes.String
      queryable: true
      modelKey: 'name'

module.exports = Tag