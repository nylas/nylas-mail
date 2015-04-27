Reflux = require 'reflux'
NamespaceStore = require './namespace-store'
Actions = require '../actions'

Location = {}
Sheet = {}

###
Public: The WorkspaceStore manages Sheets and layout modes in the application.
Observing the WorkspaceStore makes it easy to monitor the sheet stack.
###
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

  ###
  Inbound Events
  ###

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

  ###
  Accessing Data
  ###

  # Returns a {String}: The current layout mode. Either `split` or `list`
  #
  layoutMode: ->
    if @_preferredLayoutMode in @rootSheet().supportedModes
      @_preferredLayoutMode
    else
      @rootSheet().supportedModes[0]

  # Returns The top {Sheet} in the current stack. Use this method to determine
  # the sheet the user is looking at.
  #
  topSheet: ->
    @_sheetStack[@_sheetStack.length - 1]

  # Returns The {Sheet} at the root of the current stack.
  #
  rootSheet: ->
    @_sheetStack[0]

  # Returns an {Array<Sheet>} The stack of sheets
  #
  sheetStack: ->
    @_sheetStack

  ###
  Managing Sheets
  ###
  
  # * `id` {String} The ID of the Sheet being defined.
  # * `options` {Object} If the sheet should be listed in the left sidebar,
  #      pass `{root: true, name: 'Label'}`.
  # *`columns` An {Object} with keys for each layout mode the Sheet
  #      supports. For each key, provide an array of column names.
  #
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

  # Push the sheet on top of the current sheet, with a quick animation.
  # A back button will appear in the top left of the pushed sheet.
  # This method triggers, allowing observers to update.
  #
  # * `sheet` The {Sheet} type to push onto the stack.
  #
  pushSheet: (sheet) ->
    @_sheetStack.push(sheet)
    @trigger()

  # Remove the top sheet, with a quick animation. This method triggers,
  # allowing observers to update.
  popSheet: ->
    sheet = @topSheet()

    if @_sheetStack.length > 1
      @_sheetStack.pop()
      @trigger()

    if sheet is Sheet.Thread
      Actions.focusInCollection(collection: 'thread', item: null)

  # Return to the root sheet. This method triggers, allowing observers
  # to update.
  popToRootSheet: ->
    @_sheetStack.length = 1
    @trigger()

WorkspaceStore.Location = Location
WorkspaceStore.Sheet = Sheet

module.exports = WorkspaceStore
