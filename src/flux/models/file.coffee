Model = require './model'
Actions = require '../actions'
Attributes = require '../attributes'
_ = require 'underscore-plus'

module.exports =
class File extends Model

  @attributes: _.extend {}, Model.attributes,
    'filename': Attributes.String
      modelKey: 'filename'

    'size': Attributes.Number
      modelKey: 'size'

    'contentType': Attributes.String
      modelKey: 'contentType'
      jsonKey: 'content-type'

    'messageIds': Attributes.Collection
      modelKey: 'messageIds'
      jsonKey: 'message_ids'
      itemClass: String

    'isEmbedded': Attributes.Boolean
      modelKey: 'isEmbedded'
      jsonKey: 'is_embedded'
