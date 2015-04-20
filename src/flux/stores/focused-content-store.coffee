_ = require 'underscore-plus'
Reflux = require 'reflux'
NamespaceStore = require './namespace-store'
WorkspaceStore = require './workspace-store'
Actions = require '../actions'
Thread = require '../models/thread'
AddRemoveTagsTask = require '../tasks/add-remove-tags'

module.exports =
FocusedContentStore = Reflux.createStore
  init: ->
    @_resetInstanceVars()
    @listenTo NamespaceStore, @_onClear
    @listenTo WorkspaceStore, @_onWorkspaceChange
    @listenTo Actions.focusInCollection, @_onFocus
    @listenTo Actions.focusKeyboardInCollection, @_onFocusKeyboard

  _resetInstanceVars: ->
    @_focused = {}
    @_keyboardCursor = {}
    @_keyboardCursorEnabled = WorkspaceStore.layoutMode() is 'list'

  # Inbound Events

  _onClear: ->
    @_focused = {}
    @_keyboardCursor = {}
    @trigger({ impactsCollection: -> true })

  _onFocusKeyboard: ({collection, item}) ->
    throw new Error("focusKeyboard() requires a collection") unless collection
    return if @_keyboardCursor[collection]?.id is item?.id

    @_keyboardCursor[collection] = item
    @trigger({ impactsCollection: (c) -> c is collection })

  _onFocus: ({collection, item}) ->
    throw new Error("focus() requires a collection") unless collection
    return if @_focused[collection]?.id is item?.id

    @_focused[collection] = item
    @_keyboardCursor[collection] = item if item

    @trigger({ impactsCollection: (c) -> c is collection })

  _onWorkspaceChange: ->
    keyboardCursorEnabled = WorkspaceStore.layoutMode() is 'list'

    if keyboardCursorEnabled isnt @_keyboardCursorEnabled
      @_keyboardCursorEnabled = keyboardCursorEnabled

      if keyboardCursorEnabled
        for collection, item of @_focused
          @_keyboardCursor[collection] = item
        @_focused = {}
      else
        for collection, item of @_keyboardCursor
          @_onFocus({collection, item})

    @trigger({ impactsCollection: -> true })

  # Public Methods

  focused: (collection) ->
    @_focused[collection]

  focusedId: (collection) ->
    @_focused[collection]?.id

  keyboardCursor: (collection) ->
    @_keyboardCursor[collection]

  keyboardCursorId: (collection) ->
    @_keyboardCursor[collection]?.id

  keyboardCursorEnabled: ->
    @_keyboardCursorEnabled

