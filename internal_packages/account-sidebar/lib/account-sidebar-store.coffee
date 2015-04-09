Reflux = require 'reflux'
_ = require 'underscore-plus'
{DatabaseStore,
 NamespaceStore,
 Actions,
 Tag,
 Message,
 FocusedTagStore,
 Thread} = require 'inbox-exports'

AccountSidebarStore = Reflux.createStore
  init: ->
    @_setStoreDefaults()
    @_registerListeners()
    @_populate()

    # Keep a cache of unread counts since requesting the number from the
    # server is a fairly expensive operation.
    @_unreadCountCache = {}
    @localDraftsTag = new Tag({id: "drafts", name: "Local Drafts"})


  ########### PUBLIC #####################################################

  sections: ->
    @_sections

  ########### PRIVATE ####################################################

  _setStoreDefaults: ->
    @_sections = []

  _registerListeners: ->
    @listenTo DatabaseStore, @_onDataChanged
    @listenTo NamespaceStore, @_onNamespaceChanged

  _populate: ->
    namespace = NamespaceStore.current()
    return unless namespace

    DatabaseStore.findAll(Tag, namespaceId: namespace.id).then (tags) =>
      # Collect the built-in tags we want to display, and the user tags
      # (which can be identified by having non-hardcoded IDs)

      # We ignore the server drafts so we can use our own localDrafts
      tags = _.reject tags, (tag) -> tag.id is "drafts"
      tags.push(@localDraftsTag)

      mainTagIDs = ['inbox', 'drafts', 'sent', 'archive']
      mainTags = _.filter tags, (tag) -> _.contains(mainTagIDs, tag.id)
      userTags = _.reject tags, (tag) -> _.contains(mainTagIDs, tag.id)

      # Sort the main tags so they always appear in a standard order
      mainTags = _.sortBy mainTags, (tag) -> mainTagIDs.indexOf(tag.id)
      mainTags.push new Tag(name: 'All Mail', id: '*')

      # Sort user tags by name
      userTags = _.sortBy(userTags, 'name')

      lastSections = @_sections
      @_sections = [
        { label: 'Mailboxes', tags: mainTags },
        { label: 'Tags', tags: userTags },
      ]

      @trigger(@)

  _populateInboxCount: ->
    namespace = NamespaceStore.current()
    return unless namespace

    # Make a web request for unread count
    atom.inbox.makeRequest
      method: 'GET'
      path: "/n/#{namespace.id}/tags/inbox"
      returnsModel: true

  _populateDraftCount: ->
    namespace = NamespaceStore.current()
    return unless namespace

    DatabaseStore.count(Message, draft: true).then (count) =>
      @localDraftsTag.unreadCount = count
      @trigger(@)


  _refetchFromAPI: ->
    namespace = NamespaceStore.current()
    return unless namespace
    atom.inbox.getCollection(namespace.id, 'tags')

  # Inbound Events

  _onNamespaceChanged: ->
    @_refetchFromAPI()
    @_populateInboxCount()
    @_populate()

  _onDataChanged: (change) ->
    @populateInboxCountDebounced ?= _.debounce ->
      @_populateInboxCount()
    , 1000
    @populateDraftCountDebounced ?= _.debounce ->
      @_populateDraftCount()
    , 1000

    if change.objectClass is Tag.name
      @_populate()
    if change.objectClass is Thread.name
      @populateInboxCountDebounced()
    if change.objectClass is Message.name
      return unless _.some change.objects, (msg) -> msg.draft
      @populateDraftCountDebounced()

module.exports = AccountSidebarStore
