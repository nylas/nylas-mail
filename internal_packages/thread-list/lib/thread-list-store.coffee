_ = require 'underscore'
NylasStore = require 'nylas-store'

{Thread,
 Message,
 Actions,
 SearchView,
 DatabaseView,
 DatabaseStore,
 AccountStore,
 WorkspaceStore,
 FocusedContentStore,
 TaskQueueStatusStore,
 FocusedMailViewStore} = require 'nylas-exports'

# Public: A mutable text container with undo/redo support and the ability
# to annotate logical regions in the text.
class ThreadListStore extends NylasStore
  constructor: ->
    @_resetInstanceVars()

    @listenTo DatabaseStore, @_onDataChanged
    @listenTo AccountStore, @_onAccountChanged
    @listenTo FocusedMailViewStore, @_onMailViewChanged
    @createView()

    NylasEnv.commands.add "body",
      'thread-list:select-read'     : @_onSelectRead
      'thread-list:select-unread'   : @_onSelectUnread
      'thread-list:select-starred'  : @_onSelectStarred
      'thread-list:select-unstarred': @_onSelectUnstarred

    # We can't create a @view on construction because the CategoryStore
    # has hot yet been populated from the database with the list of
    # categories and their corresponding ids. Once that is ready, the
    # CategoryStore will trigger, which will update the
    # FocusedMailViewStore, which will cause us to create a new
    # @view.

  _resetInstanceVars: ->
    @_lastQuery = null

  view: ->
    @_view

  setView: (view) ->
    @_viewUnlisten() if @_viewUnlisten
    @_view = view

    @_viewUnlisten = view.listen ->
      @trigger(@)
    ,@

    # Set up a one-time listener to focus an item in the new view
    if WorkspaceStore.layoutMode() is 'split'
      unlisten = view.listen ->
        if view.loaded()
          Actions.setFocus(collection: 'thread', item: view.get(0))
          unlisten()

    @trigger(@)

  createView: ->
    mailViewFilter = FocusedMailViewStore.mailView()
    account = AccountStore.current()
    return unless account and mailViewFilter

    if mailViewFilter.searchQuery
      @setView(new SearchView(mailViewFilter.searchQuery, account.id))
    else
      matchers = []
      matchers.push Thread.attributes.accountId.equal(account.id)
      matchers = matchers.concat(mailViewFilter.matchers())

      view = new DatabaseView Thread, {matchers}, (ids) =>
        DatabaseStore.findAll(Message)
        .where(Message.attributes.threadId.in(ids))
        .where(Message.attributes.accountId.equal(account.id))
        .then (messages) ->
          messagesByThread = {}
          for id in ids
            messagesByThread[id] = []
          for message in messages
            messagesByThread[message.threadId].push message
          messagesByThread
      @setView(view)

    Actions.setFocus(collection: 'thread', item: null)

  _onSelectRead: =>
    items = @_view.itemsCurrentlyInViewMatching (item) -> not item.unread
    @_view.selection.set(items)

  _onSelectUnread: =>
    items = @_view.itemsCurrentlyInViewMatching (item) -> item.unread
    @_view.selection.set(items)

  _onSelectStarred: =>
    items = @_view.itemsCurrentlyInViewMatching (item) -> item.starred
    @_view.selection.set(items)

  _onSelectUnstarred: =>
    items = @_view.itemsCurrentlyInViewMatching (item) -> not item.starred
    @_view.selection.set(items)

  # Inbound Events

  _onMailViewChanged: ->
    @createView()

  _onAccountChanged: ->
    accountId = AccountStore.current()?.id
    accountMatcher = (m) ->
      m.attribute() is Thread.attributes.accountId and m.value() is accountId

    return if @_view and _.find(@_view.matchers(), accountMatcher)
    @createView()

  _onDataChanged: (change) ->
    return unless @_view

    if change.objectClass is Thread.name
      focusedId = FocusedContentStore.focusedId('thread')
      keyboardId = FocusedContentStore.keyboardCursorId('thread')
      viewModeAutofocuses = WorkspaceStore.layoutMode() is 'split' or WorkspaceStore.topSheet().root is true

      focusedIndex = @_view.indexOfId(focusedId)
      keyboardIndex = @_view.indexOfId(keyboardId)

      shiftIndex = (i) =>
        if i > 0 and (@_view.get(i - 1)?.unread or i >= @_view.count())
          return i - 1
        else
          return i

      @_view.invalidate({change: change, shallow: true})

      focusedLost = focusedIndex >= 0 and @_view.indexOfId(focusedId) is -1
      keyboardLost = keyboardIndex >= 0 and @_view.indexOfId(keyboardId) is -1

      if viewModeAutofocuses and focusedLost
        Actions.setFocus(collection: 'thread', item: @_view.get(shiftIndex(focusedIndex)))

      if keyboardLost
        Actions.setCursorPosition(collection: 'thread', item: @_view.get(shiftIndex(keyboardIndex)))

    if change.objectClass is Message.name
      # Important: Until we optimize this so that it detects the set change
      # and avoids a query, this should be defered since it's very unimportant
      _.defer =>
        threadIds = _.uniq _.map change.objects, (m) -> m.threadId
        @_view.invalidateMetadataFor(threadIds)


module.exports = new ThreadListStore()
