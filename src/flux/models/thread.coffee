_ = require 'underscore-plus'

Tag = require './tag'
Model = require './model'
Contact = require './contact'
Actions = require '../actions'
Attributes = require '../attributes'

Function::getter = (prop, get) ->
  Object.defineProperty @prototype, prop, {get, configurable: yes}

###
Public: The Thread model represents a Nylas Thread object. For more information
about Threads on the Nylas Platform, read the 
[https://nylas.com/docs/api#threads](Threads API Documentation)

## Attributes

`snippet`: {AttributeString} A short, ~140 character string with the content
   of the last message in the thread. Queryable.

`subject`: {AttributeString} The subject of the thread. Queryable.

`unread`: {AttributeBoolean} True if the thread is unread. Queryable.

`version`: {AttributeNumber} The version number of the thread. Thread versions increment
   when tags are changed.

`tags`: {AttributeCollection} A set of {Tag} models representing
   the tags on this thread. Queryable using the `contains` matcher.

`participants`: {AttributeCollection} A set of {Contact} models
   representing the participants in the thread.
   Note: Contacts on Threads do not have IDs.

`lastMessageTimestamp`: {AttributeDateTime} The timestamp of the
   last message on the thread.

###
class Thread extends Model

  @attributes: _.extend {}, Model.attributes,
    'snippet': Attributes.String
      modelKey: 'snippet'

    'subject': Attributes.String
      modelKey: 'subject'

    'unread': Attributes.Boolean
      queryable: true
      modelKey: 'unread'

    'version': Attributes.Number
      modelKey: 'version'

    'tags': Attributes.Collection
      queryable: true
      modelKey: 'tags'
      itemClass: Tag

    'participants': Attributes.Collection
      modelKey: 'participants'
      itemClass: Contact

    'lastMessageTimestamp': Attributes.DateTime
      queryable: true
      modelKey: 'lastMessageTimestamp'
      jsonKey: 'last_message_timestamp'

  @naturalSortOrder: ->
    Thread.attributes.lastMessageTimestamp.descending()

  @getter 'unread', -> @isUnread()

  # Public: Returns an {Array} of {Tag} IDs
  #
  tagIds: ->
    _.map @tags, (tag) -> tag.id

  # Public: Returns true if the thread has a {Tag} with the given ID.
  #
  # * `id` A {String} {Tag} ID
  #
  hasTagId: (id) ->
    @tagIds().indexOf(id) != -1

  # Public: Returns a {Boolean}, true if the thread is unread.
  isUnread: ->
    @hasTagId('unread')

  # Public: Returns a {Boolean}, true if the thread is starred.
  isStarred: ->
    @hasTagId('starred')

  star: ->
    @addRemoveTags(['starred'], [])

  unstar: ->
    @addRemoveTags([], ['starred'])

  toggleStar: ->
    if @isStarred()
      @unstar()
    else
      @star()

  addRemoveTags: (tagIdsToAdd, tagIdsToRemove) ->
    # start web change, which will dispatch more actions
    AddRemoveTagsTask = require '../tasks/add-remove-tags'
    task = new AddRemoveTagsTask(@id, tagIdsToAdd, tagIdsToRemove)
    Actions.queueTask(task)


module.exports = Thread
