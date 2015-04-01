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
    @_tag = null

  # Inbound Events

  _onClearTag: ->
    @_tag = new Tag(id: 'inbox', name: 'inbox')
    @trigger()

  _onFocusTag: (tag) ->
    return if @_tag?.id is tag?.id

    if @_tag is null and tag
      Actions.searchQueryCommitted('')

    @_tag = tag
    @trigger()

  _onSearchQueryCommitted: (query) ->
    if query? and query isnt ""
      @_oldTag = @_tag
      @_tag = null
    else
      @_tag = @_oldTag
    @trigger()

  # Public Methods
  
  tag: ->
    @_tag

  tagId: ->
    @_tag?.id

module.exports = FocusedTagStore
