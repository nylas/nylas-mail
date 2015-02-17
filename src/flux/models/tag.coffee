Model = require './model'
Attributes = require '../attributes'
_ = require 'underscore-plus'

class Tag extends Model

  @attributes: _.extend {}, Model.attributes,
    'name': Attributes.String
      queryable: true
      modelKey: 'name'
    'readonly': Attributes.Boolean
      modelKey: 'readonly'
    'unreadCount': Attributes.Number
      modelKey: 'unreadCount'
      jsonKey: 'unread_count'
    'threadCount': Attributes.Number
      modelKey: 'threadCount'
      jsonKey: 'thread_count'

module.exports = Tag