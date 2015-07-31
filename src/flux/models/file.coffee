path = require 'path'
Model = require './model'
Actions = require '../actions'
Attributes = require '../attributes'
_ = require 'underscore'

###
Public: File model represents a File object served by the Nylas Platform API.
For more information about Files on the Nylas Platform, read the
[Files API Documentation](https://nylas.com/docs/api#files)

## Attributes

`filename`: {AttributeString} The display name of the file. Queryable.

`size`: {AttributeNumber} The size of the file, in bytes.

`contentType`: {AttributeString} The content type of the file (ex: `image/png`)

`contentId`: {AttributeString} If this file is an inline attachment, contentId
is a string that matches a cid:<value> found in the HTML body of a {Message}.

This class also inherits attributes from {Model}

Section: Models
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

  # Public: Files can have empty names, or no name. `displayName` returns the file's
  # name if one is present, and falls back to appropriate default name based on
  # the contentType. It will always return a non-empty string.
  #
  displayName: ->
    defaultNames = {
      'text/calendar': "Event.ics",
      'image/png': 'Unnamed Image.png'
      'image/jpg': 'Unnamed Image.jpg'
      'image/jpeg': 'Unnamed Image.jpg'
    }
    if @filename and @filename.length
      return @filename
    else if defaultNames[@contentType]
      return defaultNames[@contentType]
    else
      return "Unnamed Attachment"

  # Public: Returns the file extension that should be used for this file.
  # Note that asking for the displayExtension is more accurate than trying to read
  # the extension directly off the filename, and may be based on contentType.
  #
  # Returns the extension without the leading '.' (ex: 'png', 'pdf')
  #
  displayExtension: ->
    path.extname(@displayName())[1..-1]

module.exports = File
