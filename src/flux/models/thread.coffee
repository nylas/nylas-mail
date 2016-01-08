_ = require 'underscore'

Label = require './label'
Folder = require './folder'
Model = require './model'
Contact = require './contact'
Actions = require '../actions'
Attributes = require '../attributes'

Function::getter = (prop, get) ->
  Object.defineProperty @prototype, prop, {get, configurable: yes}

###
Public: The Thread model represents a Thread object served by the Nylas Platform API.
For more information about Threads on the Nylas Platform, read the
[Threads API Documentation](https://nylas.com/docs/api#threads)

## Attributes

`snippet`: {AttributeString} A short, ~140 character string with the content
   of the last message in the thread. Queryable.

`subject`: {AttributeString} The subject of the thread. Queryable.

`unread`: {AttributeBoolean} True if the thread is unread. Queryable.

`starred`: {AttributeBoolean} True if the thread is starred. Queryable.

`version`: {AttributeNumber} The version number of the thread.

`participants`: {AttributeCollection} A set of {Contact} models
   representing the participants in the thread.
   Note: Contacts on Threads do not have IDs.

`lastMessageReceivedTimestamp`: {AttributeDateTime} The timestamp of the
   last message on the thread.

This class also inherits attributes from {Model}

Section: Models
###
class Thread extends Model

  @attributes: _.extend {}, Model.attributes,
    'snippet': Attributes.String
      modelKey: 'snippet'

    'subject': Attributes.String
      queryable: true
      modelKey: 'subject'

    'unread': Attributes.Boolean
      queryable: true
      modelKey: 'unread'

    'starred': Attributes.Boolean
      queryable: true
      modelKey: 'starred'

    'version': Attributes.Number
      queryable: true
      modelKey: 'version'

    'folders': Attributes.Collection
      queryable: true
      modelKey: 'folders'
      itemClass: Folder

    'labels': Attributes.Collection
      queryable: true
      modelKey: 'labels'
      itemClass: Label

    'participants': Attributes.Collection
      modelKey: 'participants'
      itemClass: Contact

    'hasAttachments': Attributes.Boolean
      modelKey: 'has_attachments'

    'lastMessageReceivedTimestamp': Attributes.DateTime
      queryable: true
      modelKey: 'lastMessageReceivedTimestamp'
      jsonKey: 'last_message_received_timestamp'

  @naturalSortOrder: ->
    Thread.attributes.lastMessageReceivedTimestamp.descending()

  @additionalSQLiteConfig:
    setup: ->
      ['CREATE INDEX IF NOT EXISTS ThreadListIndex ON Thread(account_id, last_message_received_timestamp DESC, id)']

  fromJSON: (json) ->
    super(json)

  # Public: Returns true if the thread has a {Category} with the given
  # name. Note, only `CategoryStore::standardCategories` have valid
  # `names`
  #
  # * `id` A {String} {Category} name
  #
  categoryNamed: (name) ->
    return null unless name
    for folder in (@folders ? [])
      return folder if folder.name is name
    for label in (@labels ? [])
      return label if label.name is name
    return null
  labelNamed: (name) -> @categoryNamed(name)?
  folderNamed: (name) -> @categoryNamed(name)?

  sortedLabels: ->
    return [] unless @labels
    out = []

    CategoryStore = require '../stores/category-store'

    isImportant = (l) -> l.name is 'important'
    isStandardCategory = (l) -> l.isStandardCategory()
    isUnhiddenStandardLabel = (l) ->
      not isImportant(l) and \
      isStandardCategory(l) and\
      not (l.name.isHiddenCategory())

    importantLabel = _.find @labels, isImportant
    out = out.concat importantLabel if importantLabel

    standardLabels = _.filter @labels, isUnhiddenStandardLabel
    out = out.concat standardLabels if standardLabels.length

    userLabels = _.filter @labels, (l) ->
      not isImportant(l) and not isStandardCategory(l)
    out = out.concat _.sortBy(userLabels, 'displayName') if userLabels.length

    out

module.exports = Thread
