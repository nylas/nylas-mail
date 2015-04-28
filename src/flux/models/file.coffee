Model = require './model'
Actions = require '../actions'
Attributes = require '../attributes'
_ = require 'underscore-plus'

###
Public: Files are small objects that wrap attachments and other files available via the API.
###
class File extends Model

  @attributes: _.extend {}, Model.attributes,
    'filename': Attributes.String
      modelKey: 'filename'
      jsonKey: 'filename'
      queryable: true

    'size': Attributes.Number
      modelKey: 'size'
      jsonKey: 'size'

    'contentType': Attributes.String
      modelKey: 'contentType'
      jsonKey: 'content_type'

    'messageIds': Attributes.Collection
      modelKey: 'messageIds'
      jsonKey: 'message_ids'
      itemClass: String

    'contentId': Attributes.String
      modelKey: 'contentId'
      jsonKey: 'content_id'


module.exports = File
