Reflux = require 'reflux'
_ = require 'underscore-plus'
{DatabaseStore,
 NamespaceStore,
 WorkspaceStore,
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

  ########### PUBLIC #####################################################

  sections: ->
    @_sections

  selected: ->
    if WorkspaceStore.rootSheet() is WorkspaceStore.Sheet.Threads
      FocusedTagStore.tag()
    else
      WorkspaceStore.rootSheet()

  ########### PRIVATE ####################################################

  _setStoreDefaults: ->
    @_sections = []

  _registerListeners: ->
    @listenTo DatabaseStore, @_onDataChanged
    @listenTo NamespaceStore, @_onNamespaceChanged
    @listenTo WorkspaceStore, @_onWorkspaceChanged
    @listenTo FocusedTagStore, @_onFocusChange

  _populate: ->
    namespace = NamespaceStore.current()
    return unless namespace

    DatabaseStore.findAll(Tag, namespaceId: namespace.id).then (tags) =>
      # Collect the built-in tags we want to display, and the user tags
      # (which can be identified by having non-hardcoded IDs)

      # We ignore the server drafts so we can use our own localDrafts
      tags = _.reject tags, (tag) -> tag.id is "drafts"

      # We ignore the trash tag because you can't trash anything
      tags = _.reject tags, (tag) -> tag.id is "trash"

      mainTagIDs = ['inbox', 'drafts', 'sent', 'archive']
      mainTags = _.filter tags, (tag) -> _.contains(mainTagIDs, tag.id)
      userTags = _.reject tags, (tag) -> _.contains(mainTagIDs, tag.id)

      # Sort the main tags so they always appear in a standard order
      mainTags = _.sortBy mainTags, (tag) -> mainTagIDs.indexOf(tag.id)
      mainTags.push new Tag(name: 'All Mail', id: '*')

      # Sort user tags by name
      userTags = _.sortBy(userTags, 'name')

      # Find root views, add the Views section
      rootSheets = _.filter WorkspaceStore.Sheet, (sheet) -> sheet.root and sheet.name

      lastSections = @_sections
      @_sections = [
        { label: 'Mailboxes', items: mainTags, type: 'tag' },
        { label: 'Views', items: rootSheets, type: 'sheet' },
        { label: 'Tags', items: userTags, type: 'tag' },
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

  _onWorkspaceChanged: ->
    @_populate()

  _onFocusChange: ->
    @trigger(@)

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
