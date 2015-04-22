Reflux = require 'reflux'
_ = require 'underscore-plus'

{DatabaseStore,
 SearchView,
 NamespaceStore,
 FocusedContentStore,
 Actions,
 Utils,
 Thread,
 Message} = require 'inbox-exports'

module.exports =
SearchStore = Reflux.createStore
  init: ->
    @_resetInstanceVars()

    @listenTo Actions.searchQueryCommitted, @_onSearchCommitted
    @listenTo Actions.searchWeightsChanged, @_onSearchWeightsChanged
    @listenTo DatabaseStore, @_onDataChanged
    @listenTo NamespaceStore, @_onNamespaceChanged

  _resetInstanceVars: ->
    @_lastQuery = null
    @_searchQuery = null
    @_searchWeights = {"from": 4, "subject": 2}

  view: ->
    @_view

  searchWeights: ->
    @_searchWeights

  searchQuery: ->
    @_searchQuery

  setView: (view) ->
    @_viewUnlisten() if @_viewUnlisten
    @_view = view

    if view
      @_viewUnlisten = view.listen ->
        @trigger(@)
      ,@

    @trigger(@)

  createView: ->
    namespaceId = NamespaceStore.current()?.id

    if @_searchQuery
      query = JSON.parse(JSON.stringify(@_searchQuery))
      for term in query
        if term['all']
          term['weights'] = @_searchWeights

      v = new SearchView(query, namespaceId)
      v.setSortOrder('relevance')
      @setView(v)
    else
      @setView(null)

    Actions.focusInCollection(collection: 'thread', item: null)

  # Inbound Events

  _onNamespaceChanged: ->
    @createView()

  _onSearchCommitted: (query) ->
    @_searchQuery = query
    @createView()

  _onSearchWeightsChanged: (weights) ->
    @_searchWeights = weights

    @createViewDebounced ?= _.debounce =>
      @createView()
    , 500
    @createViewDebounced()
    @trigger(@)

  _onDataChanged: (change) ->
    return unless @_view

    if change.objectClass is Thread.name
      @_view.invalidate({changed: change.objects, shallow: true})

    if change.objectClass is Message.name
      threadIds = _.uniq _.map change.objects, (m) -> m.threadId
      @_view.invalidateMetadataFor(threadIds)
