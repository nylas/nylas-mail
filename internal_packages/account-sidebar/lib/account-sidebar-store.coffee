Reflux = require 'reflux'
_ = require 'underscore'
{DatabaseStore,
 NamespaceStore,
 WorkspaceStore,
 UnreadCountStore,
 DraftCountStore,
 Actions,
 Tag,
 Message,
 FocusedTagStore,
 NylasAPI,
 Thread} = require 'nylas-exports'

AccountSidebarStore = Reflux.createStore
  init: ->
    @_tags = []

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
    @listenTo UnreadCountStore, @_onCountChanged
    @listenTo DraftCountStore, @_onCountChanged
    @listenTo FocusedTagStore, @_onFocusChange

  _populate: ->
    namespace = NamespaceStore.current()
    return unless namespace

    DatabaseStore.findAll(Tag, namespaceId: namespace.id).then (tags) =>
      @_tags = tags
      @_build()

  _build: ->
    tags = @_tags

    # Collect the built-in tags we want to display, and the user tags
    # (which can be identified by having non-hardcoded IDs)

    # We ignore the server drafts so we can use our own localDrafts
    tags = _.reject tags, (tag) -> tag.id is "drafts"

    # We ignore the trash tag because you can't trash anything
    tags = _.reject tags, (tag) -> tag.id is "trash"

    # Clone the tag objects so that components holding on to tags
    # don't have identical object references with new data.
    tags = _.map tags, (tag) -> new Tag(tag)

    mainTagIDs = ['inbox', 'starred', 'drafts', 'sent', 'archive']
    mainTags = _.filter tags, (tag) -> _.contains(mainTagIDs, tag.id)
    userTags = _.reject tags, (tag) -> _.contains(mainTagIDs, tag.id)

    # Sort the main tags so they always appear in a standard order
    mainTags = _.sortBy mainTags, (tag) -> mainTagIDs.indexOf(tag.id)
    mainTags.push new Tag(name: 'All Mail', id: Tag.AllMailID)

    # Add the counts
    inboxTag = _.find tags, (tag) -> tag.id is 'inbox'
    inboxTag?.unreadCount = UnreadCountStore.count()

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
    @_populate()

  _onWorkspaceChanged: ->
    @_populate()

  _onCountChanged: ->
    @_build()

  _onFocusChange: ->
    @trigger(@)

  _onDataChanged: (change) ->
    if change.objectClass is Tag.name
      @_populate()

module.exports = AccountSidebarStore
