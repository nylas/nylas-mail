Reflux = require 'reflux'
NamespaceStore = require './namespace-store'
Actions = require '../actions'

WorkspaceStore = Reflux.createStore
  init: ->
    @_resetInstanceVars()

    @listenTo Actions.selectView, @_onSelectView
    @listenTo Actions.selectLayoutMode, @_onSelectLayoutMode

    @listenTo Actions.popSheet, @popSheet
    @listenTo Actions.searchQueryCommitted, @popToRootSheet
    @listenTo Actions.selectThreadId, @pushThreadSheet
    atom.commands.add 'body',
      'application:pop-sheet': => @popSheet()

  _resetInstanceVars: ->
    @_sheetStack = ["Root"]
    @_view = 'threads'
    @_layoutMode = 'list'

  # Inbound Events

  _onSelectView: (view) ->
    @_view = view
    @trigger(@)

  _onSelectLayoutMode: (mode) ->
    @_layoutMode = mode
    @trigger(@)

  # Accessing Data

  selectedView: ->
    @_view

  selectedLayoutMode: ->
    @_layoutMode

  sheet: ->
    @_sheetStack[@_sheetStack.length - 1]

  sheetStack: ->
    @_sheetStack

  # Managing Sheets

  pushSheet: (type) ->
    @_sheetStack.push(type)
    @trigger()
  
  pushThreadSheet: (threadId) ->
    if @selectedLayoutMode() is 'list' and threadId and @sheet() isnt "Thread"
      @pushSheet("Thread")

  popSheet: ->
    if @_sheetStack.length > 1
      @_sheetStack.pop()
      @trigger()

  popToRootSheet: ->
    if @_sheetStack.length > 1
      @_sheetStack = ["Root"]
      @trigger()


module.exports = WorkspaceStore
