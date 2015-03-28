Reflux = require 'reflux'
_ = require 'underscore-plus'
{DatabaseStore, NamespaceStore, Actions, Tag, Message, Thread} = require 'inbox-exports'

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

  selectedId: ->
    @_selectedId

  ########### PRIVATE ####################################################

  _setStoreDefaults: ->
    @_sections = []
    @_selectedId = null

  _registerListeners: ->
    @listenTo Actions.selectTagId, @_onSelectTagId
    @listenTo Actions.searchQueryCommitted, @_onSearchQueryCommitted
    @listenTo DatabaseStore, @_onDataChanged
    @listenTo NamespaceStore, @_onNamespaceChanged

  _onSearchQueryCommitted: (query) ->
    if query? and query isnt ""
      @_oldSelectedId = @_selectedId
      @_selectedId = "search"
    else
      @_selectedId = @_oldSelectedId if @_oldSelectedId

    @trigger(@)

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
      userTags = _.filter tags, (tag) -> tag.name != tag.id

      # Sort the main tags so they always appear in a standard order
      mainTags = _.sortBy mainTags, (tag) -> mainTagIDs.indexOf(tag.id)
      mainTags.push new Tag(name: 'All Mail', id: '*')

      lastSections = @_sections
      @_sections = [
        { label: 'Mailboxes', tags: mainTags }
      ]

      if _.isEqual(@_sections, lastSections) is false
        @_populateUnreadCounts()
      @trigger(@)

  _populateUnreadCounts: ->
    namespace = NamespaceStore.current()
    return unless namespace

    @_sections.forEach (section) =>
      section.tags.forEach (tag) =>
        if tag.id is "drafts"
          @_populateDraftsCount(tag)
        else if tag.id in ['drafts', 'sent', 'archive', 'trash', '*']
          return
        else
          # Make a web request for unread count
          atom.inbox.makeRequest
            method: 'GET'
            path: "/n/#{namespace.id}/tags/#{tag.id}"
            returnsModel: true

  _populateDraftsCount: ->
    namespace = NamespaceStore.current()
    return unless namespace

    DatabaseStore.count(Message, draft: true).then (count) =>
      @localDraftsTag.unreadCount = count
      @trigger(@)

  # Unfortunately, the joins necessary to compute unread counts are expensive.
  # Rather than update unread counts every time threads change in the database,
  # we debounce aggressively and update only after changes have stopped.
  # Remove this when JOIN query speed is fixed!
  _populateUnreadCountsDebounced: _.debounce ->
    @_populateUnreadCounts()
  , 1000

  _refetchFromAPI: ->
    namespace = NamespaceStore.current()
    return unless namespace

    # Trigger a request to the API
    atom.inbox.getCollection(namespace.id, 'tags')

  # Inbound Events

  _onNamespaceChanged: ->
    @_refetchFromAPI()
    @_populate()

  _onDataChanged: (change) ->
    if change.objectClass == Tag.name
      @_populate()
    if change.objectClass == Thread.name
      @_populateUnreadCountsDebounced()
    if change.objectClass == Message.name
      @_populateDraftsCount()

  _onSelectTagId: (tagId) ->
    Actions.searchQueryCommitted('') if @_selectedId is "search"
    @_selectedId = tagId
    @trigger(@)

module.exports = AccountSidebarStore
