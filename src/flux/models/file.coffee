Model = require './model'
Actions = require '../actions'
Attributes = require '../attributes'
_ = require 'underscore-plus'

###
Public: File model represents a File object served by the Nylas Platform API.
For more information about Files on the Nylas Platform, read the
[https://nylas.com/docs/api#files](Files API Documentation)

## Attributes

`snippet`: {AttributeString} A short, ~140 character string with the content
   of the last message in the thread. Queryable.

This class also inherits attributes from {Model}

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
