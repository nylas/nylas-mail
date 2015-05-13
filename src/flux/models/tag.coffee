Model = require './model'
Attributes = require '../attributes'
_ = require 'underscore-plus'

###
Public: The Tag model represents a Nylas Tag object. For more information
about Tags on the Nylas Platform, read the
[Tags API Documentation](https://nylas.com/docs/api#tags)

## Attributes

`name`: {AttributeString} The display-friendly name of the tag. Queryable.

`readonly`: {AttributeBoolean} True if the tag is read-only. See the Nylas
 API documentation for more information about what tags are read-only.

`unreadCount`: {AttributeNumber} The number of unread threads with the tag.
  Note: This attribute is only available when a single tag is fetched directly
  from the Nylas API, not when all tags are listed.

`threadCount`: {AttributeNumber} The number of threads with the tag.
  Note: This attribute is only available when a single tag is fetched directly
  from the Nylas API, not when all tags are listed.

Section: Models
###
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
