_ = require 'underscore'
Category = require './category'
Attributes = require '../attributes'

###
Public: The Label model represents a Nylas Label object. For more
information about Label on the Nylas Platform, read the [Label API
Documentation](https://nylas.com/docs/api#folders)

NOTE: This is different from a `Folder`. A `Folder` is used for generic
IMAP and Exchange, while `Label`s are used for Gmail. The `Namespace` has
the filed `organizationUnit` which specifies if the current namespace uses
either "folder" or "label".

While the two appear fairly similar, they have different behavioral
semantics and are treated separately.

Nylas also exposes a set of standard types or categories of folders/
labels: an extended version of [rfc-6154]
(http://tools.ietf.org/html/rfc6154), returned as the name of the folder/
label:
  - inbox
  - all
  - trash
  - archive
  - drafts
  - sent
  - spam
  - important

NOTE: "starred" and "unread" are no longer folder nor labels. They are now
boolean values on messages and threads.

## Attributes

`name`: {AttributeString} The internal name of the label. Queryable.

`displayName`: {AttributeString} The display-friendly name of the label. Queryable.

Section: Models
###
class Label extends Category

  @additionalSQLiteConfig:
    setup: ->
      ['CREATE INDEX IF NOT EXISTS LabelNameIndex ON Label(name)']

module.exports = Label
