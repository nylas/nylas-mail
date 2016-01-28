NylasStore = require "nylas-store"
Actions = require "../actions"
Message = require "../models/message"
Thread = require "../models/thread"
Utils = require '../models/utils'
DatabaseStore = require "./database-store"
AccountStore = require "./account-store"
FocusedContentStore = require "./focused-content-store"
ChangeUnreadTask = require '../tasks/change-unread-task'
NylasAPI = require '../nylas-api'
ExtensionRegistry = require '../../extension-registry'
{deprecate} = require '../../deprecate-utils'
async = require 'async'
_ = require 'underscore'

class MessageStore extends NylasStore

  constructor: ->
    @_setStoreDefaults()
    @_registerListeners()

  ########### PUBLIC #####################################################

  items: ->
    @_items

  threadId: -> @_thread?.id

  thread: -> @_thread

  itemsExpandedState: =>
    # ensure that we're always serving up immutable objects.
    # this.state == nextState is always true if we modify objects in place.
    _.clone @_itemsExpanded

  hasCollapsedItems: ->
    _.size(@_itemsExpanded) < @_items.length

  itemClientIds: ->
    _.pluck(@_items, "clientId")

  itemsLoading: ->
    @_itemsLoading

  ###
  Message Store Extensions
  ###

  # Public: Returns the extensions registered with the MessageStore.
  extensions: =>
    ExtensionRegistry.MessageView.extensions()

  # Public: Deprecated, use {ExtensionRegistry.MessageView.register} instead.
  # Registers a new extension with the MessageStore. MessageStore extensions
  # make it possible to customize message body parsing, and will do more in
  # the future.
  #
  # - `ext` A {MessageViewExtension} instance.
  #
  registerExtension: (ext) =>
    ExtensionRegistry.MessageView.register(ext)

  # Public: Deprecated, use {ExtensionRegistry.MessageView.unregister} instead.
  # Unregisters the extension provided from the MessageStore.
  #
  # - `ext` A {MessageViewExtension} instance.
  #
  unregisterExtension: (ext) =>
    ExtensionRegistry.MessageView.unregister(ext)

  _onExtensionsChanged: (role) ->
    MessageBodyProcessor = require './message-body-processor'
    MessageBodyProcessor.resetCache()


  ########### PRIVATE ####################################################

  _setStoreDefaults: =>
    @_items = []
    @_itemsExpanded = {}
    @_itemsLoading = false
    @_thread = null
    @_inflight = {}

  _registerListeners: ->
    @listenTo ExtensionRegistry.MessageView, @_onExtensionsChanged
    @listenTo DatabaseStore, @_onDataChanged
    @listenTo FocusedContentStore, @_onFocusChanged
    @listenTo Actions.toggleMessageIdExpanded, @_onToggleMessageIdExpanded
    @listenTo Actions.toggleAllMessagesExpanded, @_onToggleAllMessagesExpanded

  _onDataChanged: (change) =>
    return unless @_thread

    if change.objectClass is Message.name
      inDisplayedThread = _.some change.objects, (obj) => obj.threadId is @_thread.id
      return unless inDisplayedThread

      if change.objects.length is 1 and change.objects[0].draft is true
        item = change.objects[0]
        itemIndex = _.findIndex @_items, (msg) -> msg.id is item.id or msg.clientId is item.clientId

        if change.type is 'persist' and itemIndex is -1
          @_items = [].concat(@_items, [item])
          @_items = @_sortItemsForDisplay(@_items)
          @_expandItemsToDefault()
          @trigger()
          return

        if change.type is 'unpersist' and itemIndex isnt -1
          @_items = [].concat(@_items)
          @_items.splice(itemIndex, 1)
          @_expandItemsToDefault()
          @trigger()
          return

      @_fetchFromCache()

    if change.objectClass is Thread.name
      updatedThread = _.find change.objects, (obj) => obj.id is @_thread.id
      if updatedThread
        @_thread = updatedThread
        @_fetchFromCache()

  _onFocusChanged: (change) =>
    return unless change.impactsCollection('thread')

    # This implements a debounce that fires on the leading and trailing edge.
    #
    # If we haven't changed focus in the last 100ms, do it immediately. This means
    # there is no delay when moving to the next thread, deselecting a thread, etc.
    #
    # If we have changed focus in the last 100ms, wait for focus changes to
    # stop arriving for 100msec before applying. This means that flying
    # through threads doesn't cause is to make a zillion queries for messages.
    #
    if not @_onFocusChangedTimer
      @_onApplyFocusChange()
    else
      clearTimeout(@_onFocusChangedTimer)

    @_onFocusChangedTimer = setTimeout =>
      @_onFocusChangedTimer = null
      @_onApplyFocusChange()
    , 100

  _onApplyFocusChange: =>
    focused = FocusedContentStore.focused('thread')
    return if @_thread?.id is focused?.id

    @_thread = focused
    @_items = []
    @_itemsLoading = true
    @_itemsExpanded = {}
    @trigger()

    @_fetchFromCache()

  _markAsRead: ->
    # Mark the thread as read if necessary. Make sure it's still the
    # current thread after the timeout.
    #
    # Override canBeUndone to return false so that we don't see undo
    # prompts (since this is a passive action vs. a user-triggered
    # action.)
    return if not @_thread
    return if @_lastLoadedThreadId is @_thread.id
    @_lastLoadedThreadId = @_thread.id

    if @_thread.unread
      markAsReadDelay = NylasEnv.config.get('core.reading.markAsReadDelay')
      markAsReadId = @_thread.id
      return if markAsReadDelay < 0

      setTimeout =>
        return unless markAsReadId is @_thread?.id and @_thread.unread
        t = new ChangeUnreadTask(thread: @_thread, unread: false)
        t.canBeUndone = => false
        Actions.queueTask(t)
      , markAsReadDelay

  _onToggleAllMessagesExpanded: =>
    if @hasCollapsedItems()
      @_items.forEach @_expandItem
    else
      # Do not collapse the latest message, i.e. the last one
      @_items[...-1].forEach @_collapseItem
    @trigger()

  _onToggleMessageIdExpanded: (id) =>
    item = _.findWhere(@_items, {id})
    return unless item

    if @_itemsExpanded[id]
      @_collapseItem(item)
    else
      @_expandItem(item)
    @trigger()

  _expandItem: (item) =>
    @_itemsExpanded[item.id] = "explicit"
    @_fetchExpandedBodies([item])
    @_fetchExpandedAttachments([item])

  _collapseItem: (item) =>
    delete @_itemsExpanded[item.id]

  _fetchFromCache: (options = {}) ->
    return unless @_thread

    loadedThreadId = @_thread.id

    query = DatabaseStore.findAll(Message)
    query.where(threadId: loadedThreadId)
    query.include(Message.attributes.body)
    query.then (items) =>
      # Check to make sure that our thread is still the thread we were
      # loading items for. Necessary because this takes a while.
      return unless loadedThreadId is @_thread?.id

      loaded = true

      @_items = @_sortItemsForDisplay(items)

      # If no items were returned, attempt to load messages via the API. If items
      # are returned, this will trigger a refresh here.
      if @_items.length is 0
        @_fetchMessages()
        loaded = false

      @_expandItemsToDefault()

      # Download the attachments on expanded messages.
      @_fetchExpandedAttachments(@_items)

      # Check that expanded messages have bodies. We won't mark ourselves
      # as loaded until they're all available. Note that items can be manually
      # expanded so this logic must be separate from above.
      if @_fetchExpandedBodies(@_items)
        loaded = false

      # Normally, we would trigger often and let the view's
      # shouldComponentUpdate decide whether to re-render, but if we
      # know we're not ready, don't even bother.  Trigger once at start
      # and once when ready. Many third-party stores will observe
      # MessageStore and they'll be stupid and re-render constantly.
      if loaded
        @_itemsLoading = false
        @_markAsRead()
        @trigger(@)

  _fetchExpandedBodies: (items) ->
    startedAFetch = false
    for item in items
      continue unless @_itemsExpanded[item.id]
      if not _.isString(item.body)
        @_fetchMessageIdFromAPI(item.id)
        startedAFetch = true
    startedAFetch

  _fetchExpandedAttachments: (items) ->
    return unless NylasEnv.config.get('core.attachments.downloadPolicy') is 'on-read'
    for item in items
      continue unless @_itemsExpanded[item.id]
      for file in item.files
        Actions.fetchFile(file)

  # Expand all unread messages, all drafts, and the last message
  _expandItemsToDefault: ->
    for item, idx in @_items
      if item.unread or item.draft or idx is @_items.length - 1
        @_itemsExpanded[item.id] = "default"

  _fetchMessages: ->
    account = AccountStore.accountForId(@_thread.accountId)
    NylasAPI.getCollection account.id, 'messages', {thread_id: @_thread.id}

  _fetchMessageIdFromAPI: (id) ->
    return if @_inflight[id]

    @_inflight[id] = true
    account = AccountStore.accountForId(@_thread.accountId)
    NylasAPI.makeRequest
      path: "/messages/#{id}"
      accountId: account.id
      returnsModel: true
      success: =>
        delete @_inflight[id]
      error: =>
        delete @_inflight[id]

  _sortItemsForDisplay: (items) ->
    # Re-sort items in the list so that drafts appear after the message that
    # they are in reply to, when possible. First, identify all the drafts
    # with a replyToMessageId and remove them
    itemsInReplyTo = []
    for item, index in items by -1
      if item.draft and item.replyToMessageId
        itemsInReplyTo.push(item)
        items.splice(index, 1)

    # For each item with the reply header, re-inset it into the list after
    # the message which it was in reply to. If we can't find it, put it at the end.
    for item in itemsInReplyTo
      for other, index in items
        if item.replyToMessageId is other.id
          items.splice(index+1, 0, item)
          item = null
          break
      if item
        items.push(item)

    items

store = new MessageStore()
store.registerExtension = deprecate(
  'MessageStore.registerExtension',
  'ExtensionRegistry.MessageView.register',
  store,
  store.registerExtension
)
store.unregisterExtension = deprecate(
  'MessageStore.unregisterExtension',
  'ExtensionRegistry.MessageView.unregister',
  store,
  store.unregisterExtension
)
module.exports = store
