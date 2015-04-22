_ = require 'underscore-plus'

Tag = require './tag'
Model = require './model'
Contact = require './contact'
Actions = require '../actions'
Attributes = require '../attributes'

Function::getter = (prop, get) ->
  Object.defineProperty @prototype, prop, {get, configurable: yes}

module.exports =
##
# @class Thread
# @namespace Models
#
class Thread extends Model

  @attributes: _.extend {}, Model.attributes,
    ##
    # A short, ~140 character string with the content of the last message in the thread.
    # @property snippet
    # @type AttributeString
    #
    'snippet': Attributes.String
      modelKey: 'snippet'

    ##
    # The subject of the thread
    # @property subject
    # @type AttributeString
    #
    'subject': Attributes.String
      modelKey: 'subject'

    ##
    # The unread state of the thread. Queryable.
    # @property unread
    # @type AttributeBoolean
    #
    'unread': Attributes.Boolean
      queryable: true
      modelKey: 'unread'

    ##
    # The version number of the thread. Thread versions increment
    # when tags are changed.
    # @property version
    # @type AttributeNumber
    #
    'version': Attributes.Number
      modelKey: 'version'

    ##
    # A set of Tag models representing the tags on this thread.
    # Queryable using the `contains` matcher.
    # @property tags
    # @type AttributeCollection
    #
    'tags': Attributes.Collection
      queryable: true
      modelKey: 'tags'
      itemClass: Tag

    ##
    # A set of Contact models representing the participants in the thread.
    # Note: Contacts on Threads do not have IDs.
    # @property participants
    # @type AttributeCollection
    #
    'participants': Attributes.Collection
      modelKey: 'participants'
      itemClass: Contact

    ##
    # The timestamp of the last message on the thread.
    # @property lastMessageTimestamp
    # @type AttributeDateTime
    #
    'lastMessageTimestamp': Attributes.DateTime
      queryable: true
      modelKey: 'lastMessageTimestamp'
      jsonKey: 'last_message_timestamp'

  @naturalSortOrder: ->
    Thread.attributes.lastMessageTimestamp.descending()

  @getter 'unread', -> @isUnread()

  ##
  # The timestamp of the last message on the thread.
  # @return An array of Tag IDs
  #
  tagIds: ->
    _.map @tags, (tag) -> tag.id

  hasTagId: (id) ->
    @tagIds().indexOf(id) != -1

  isUnread: ->
    @hasTagId('unread')

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
