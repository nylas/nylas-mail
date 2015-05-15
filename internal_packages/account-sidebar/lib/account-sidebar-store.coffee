Reflux = require 'reflux'
_ = require 'underscore-plus'
{DatabaseStore,
 NamespaceStore,
 WorkspaceStore,
 Actions,
 Tag,
 Message,
 FocusedTagStore,
 NylasAPI,
 Thread} = require 'nylas-exports'

AccountSidebarStore = Reflux.createStore
  init: ->
    @_inboxCount = null
    @_tags = []

    @_setStoreDefaults()
    @_registerListeners()
    @_populate()
    @_populateInboxCount()

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
      @_tags = tags
      @_build()

  _populateInboxCount: ->
    namespace = NamespaceStore.current()
    return unless namespace

    DatabaseStore.count(Thread, [
      Thread.attributes.namespaceId.equal(namespace.id),
      Thread.attributes.unread.equal(true),
      Thread.attributes.tags.contains('inbox')
    ]).then (count) =>
      if count isnt @_inboxCount
        @_inboxCount = count
        @_build()

  _build: ->
    tags = @_tags

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

    inboxTag = _.find tags, (tag) -> tag.id is 'inbox'
    inboxTag?.unreadCount = @_inboxCount

    # Sort user tags by name
    userTags = _.sortBy(userTags, 'name')

    # Find root views, add the Views section
    featureSheets = _.filter WorkspaceStore.Sheet, (sheet) ->
      sheet.name in ['Today']
    extraSheets = _.filter WorkspaceStore.Sheet, (sheet) ->
      sheet.root and sheet.name and not (sheet in featureSheets)

    lastSections = @_sections
    @_sections = [
      { label: '', items: featureSheets, type: 'sheet' },
      { label: 'Mailboxes', items: mainTags, type: 'tag' },
      { label: 'Views', items: extraSheets, type: 'sheet' },
      { label: 'Tags', items: userTags, type: 'tag' },
    ]

    @trigger(@)

  _refetchFromAPI: ->
    namespace = NamespaceStore.current()
    return unless namespace
    NylasAPI.getCollection(namespace.id, 'tags')

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
    @populateInboxCountDebounced ?= _.debounce =>
      @_populateInboxCount()
    , 5000

    if change.objectClass is Tag.name
      @_populate()
    if change.objectClass is Thread.name
      @populateInboxCountDebounced()

module.exports = AccountSidebarStore
