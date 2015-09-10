_ = require 'underscore'
Category = require './category'
Attributes = require '../attributes'

###
Public: The Folder model represents a Nylas Folder object. For more
information about Folder on the Nylas Platform, read the [Folder API
Documentation](https://nylas.com/docs/api#folders)

NOTE: This is different from a `Label`. A `Folder` is used for generic
IMAP and Exchange, while `Label`s are used for Gmail. The `Namespace` has
the filed `organizationUnit` which specifies if the current account uses
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

`name`: {AttributeString} The internal name of the folder. Queryable.

`displayName`: {AttributeString} The display-friendly name of the folder. Queryable.

Section: Models
###
class Folder extends Category


  @additionalSQLiteConfig:
    setup: ->
      ['CREATE INDEX IF NOT EXISTS FolderNameIndex ON Folder(account_id,name)',
       'CREATE UNIQUE INDEX IF NOT EXISTS FolderClientIndex ON Folder(client_id)']

module.exports = Folder
