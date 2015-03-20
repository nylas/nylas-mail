Reflux = require 'reflux'
NamespaceStore = require './namespace-store'
Actions = require '../actions'

Location = {}
for key in ['RootSidebar', 'RootCenter', 'MessageList', 'MessageListSidebar']
  Location[key] = {id: "#{key}", Toolbar: {id: "#{key}:Toolbar"}}

defineSheet = (type, columns) ->
  Toolbar:
    Left: {id: "Sheet:#{type}:Toolbar:Left"}
    Right: {id: "Sheet:#{type}:Toolbar:Right"}
  Header: {id: "Sheet:#{type}:Header"}
  Footer: {id: "Sheet:#{type}:Footer"}
  type: type
  columns: columns

Sheet =
  Global: defineSheet 'Global'

  Root: defineSheet 'Root',
    list: [Location.RootSidebar, Location.RootCenter]
    split: [Location.RootSidebar, Location.RootCenter, Location.MessageList, Location.MessageListSidebar]

  Thread: defineSheet 'Thread',
    list: [Location.MessageList, Location.MessageListSidebar]


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
    @_sheetStack = [Sheet.Root]
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
    if @selectedLayoutMode() is 'list' and threadId and @sheet().type isnt Sheet.Thread.type
      @pushSheet(Sheet.Thread)

  popSheet: ->
    if @_sheetStack.length > 1
      @_sheetStack.pop()
      @trigger()

  popToRootSheet: ->
    if @_sheetStack.length > 1
      @_sheetStack = [Sheet.Root]
      @trigger()


WorkspaceStore.Location = Location
WorkspaceStore.Sheet = Sheet

module.exports = WorkspaceStore
