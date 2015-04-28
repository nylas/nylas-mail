Reflux = require 'reflux'
NamespaceStore = require './namespace-store'
Actions = require '../actions'
Tag = require '../models/tag'

FocusedTagStore = Reflux.createStore
  init: ->
    @_resetInstanceVars()

    @listenTo NamespaceStore, @_onClearTag
    @listenTo Actions.focusTag, @_onFocusTag
    @listenTo Actions.searchQueryCommitted, @_onSearchQueryCommitted

  _resetInstanceVars: ->
    @_tag = new Tag(id: 'inbox', name: 'inbox')

  # Inbound Events

  _onClearTag: ->
    @_setTag(new Tag(id: 'inbox', name: 'inbox'))

  _onFocusTag: (tag) ->
    return if @_tag?.id is tag?.id

    if @_tag is null and tag
      Actions.searchQueryCommitted('')

    @_setTag(tag)

  _onSearchQueryCommitted: (query) ->
    if query
      @_oldTag = @_tag
      @_setTag(null)
    else if @_oldTag
      @_setTag(@_oldTag)

  _setTag: (tag) ->
    return if @_tag?.id is tag?.id
    @_tag = tag
    @trigger()

  # Public Methods
  
  tag: ->
    @_tag

  tagId: ->
    return null unless @_tag
    @_tag.id

module.exports = FocusedTagStore
