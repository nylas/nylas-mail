_ = require 'underscore-plus'
Reflux = require 'reflux'
NamespaceStore = require './namespace-store'
Actions = require '../actions'
MarkThreadReadTask = require '../tasks/mark-thread-read'
AddRemoveTagsTask = require '../tasks/add-remove-tags'

FocusedThreadStore = Reflux.createStore
  init: ->
    @_resetInstanceVars()
    @listenTo NamespaceStore, @_onClearThread
    @listenTo Actions.focusThread, @_onFocusThread

  _resetInstanceVars: ->
    @_thread = null

  # Inbound Events

  _onClearThread: ->
    @_thread = null
    @trigger()

  _onFocusThread: (thread) ->
    return if @_thread?.id is thread?.id

    @_thread = thread
    if thread && thread.isUnread()
      Actions.queueTask(new MarkThreadReadTask(thread.id))

    @trigger()

  # Public Methods

  thread: ->
    @_thread

  threadId: ->
    @_thread?.id

module.exports = FocusedThreadStore
