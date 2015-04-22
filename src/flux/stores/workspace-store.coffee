Reflux = require 'reflux'
NamespaceStore = require './namespace-store'
Actions = require '../actions'

Location = {}
Sheet = {}

WorkspaceStore = Reflux.createStore
  init: ->
    @defineSheet 'Global'

    @defineSheet 'Threads', {root: true},
      list: ['RootSidebar', 'ThreadList']
      split: ['RootSidebar', 'ThreadList', 'MessageList', 'MessageListSidebar']

    @defineSheet 'Drafts', {root: true, name: 'Local Drafts'},
      list: ['RootSidebar', 'DraftList']

    @defineSheet 'Thread', {},
      list: ['MessageList', 'MessageListSidebar']

    @_resetInstanceVars()

    @listenTo Actions.selectRootSheet, @_onSelectRootSheet
    @listenTo Actions.selectLayoutMode, @_onSelectLayoutMode
    @listenTo Actions.focusInCollection, @_onFocusInCollection

    @listenTo Actions.popSheet, @popSheet
    @listenTo Actions.searchQueryCommitted, @popToRootSheet
    @listenTo Actions.logout, @popToRootSheet

    atom.commands.add 'body',
      'application:pop-sheet': => @popSheet()

  _resetInstanceVars: ->
    @_preferredLayoutMode = 'list'
    @_sheetStack = []

    @_onSelectRootSheet(Sheet.Threads)

  # Inbound Events

  _onSelectRootSheet: (sheet) ->
    if not sheet
      throw new Error("Actions.selectRootSheet - #{sheet} is not a valid sheet.")
    if not sheet.root
      throw new Error("Actions.selectRootSheet - #{sheet} is not registered as a root sheet.")

    @_sheetStack = []
    @_sheetStack.push(sheet)
    @trigger(@)

  _onSelectLayoutMode: (mode) ->
    @_preferredLayoutMode = mode
    @trigger(@)

  _onFocusInCollection: ({collection, item}) ->
    if collection is 'thread'
      if @layoutMode() is 'list'
        if item and @topSheet() isnt Sheet.Thread
          @pushSheet(Sheet.Thread)
        if not item and @topSheet() is Sheet.Thread
          @popSheet()

    if collection is 'file'
      if @layoutMode() is 'list'
        if item and @topSheet() isnt Sheet.File
          @pushSheet(Sheet.File)
        if not item and @topSheet() is Sheet.File
          @popSheet()

  # Accessing Data

  layoutMode: ->
    if @_preferredLayoutMode in @rootSheet().supportedModes
      @_preferredLayoutMode
    else
      @rootSheet().supportedModes[0]

  topSheet: ->
    @_sheetStack[@_sheetStack.length - 1]

  rootSheet: ->
    @_sheetStack[0]

  sheetStack: ->
    @_sheetStack

  # Managing Sheets

  defineSheet: (id, options = {}, columns = {}) ->
    # Make sure all the locations have definitions so that packages
    # can register things into these locations and their toolbars.
    for layout, cols of columns
      for col, idx in cols
        Location[col] ?= {id: "#{col}", Toolbar: {id: "#{col}:Toolbar"}}
        cols[idx] = Location[col]

    Sheet[id] =
      id: id
      columns: columns
      supportedModes: Object.keys(columns)

      name: options.name
      root: options.root

      Toolbar:
        Left: {id: "Sheet:#{id}:Toolbar:Left"}
        Right: {id: "Sheet:#{id}:Toolbar:Right"}
      Header: {id: "Sheet:#{id}:Header"}
      Footer: {id: "Sheet:#{id}:Footer"}

  pushSheet: (sheet) ->
    @_sheetStack.push(sheet)
    @trigger()

  popSheet: ->
    sheet = @topSheet()

    if @_sheetStack.length > 1
      @_sheetStack.pop()
      @trigger()

    if sheet is Sheet.Thread
      Actions.focusInCollection(collection: 'thread', item: null)

  popToRootSheet: ->
    @_sheetStack.length = 1
    @trigger()

WorkspaceStore.Location = Location
WorkspaceStore.Sheet = Sheet

module.exports = WorkspaceStore
