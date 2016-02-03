MultiselectSplitInteractionHandler = require '../../src/components/multiselect-split-interaction-handler'
WorkspaceStore = require '../../src/flux/stores/workspace-store'
FocusedContentStore = require '../../src/flux/stores/focused-content-store'
Thread = require '../../src/flux/models/thread'
Actions = require '../../src/flux/actions'
_ = require 'underscore'

describe "MultiselectSplitInteractionHandler", ->
  beforeEach ->
    @item = new Thread(id:'123')
    @itemFocus = new Thread({id: 'focus'})
    @itemKeyboardFocus = new Thread({id: 'keyboard-focus'})
    @itemAfterFocus = new Thread(id:'after-focus')
    @itemAfterKeyboardFocus = new Thread(id:'after-keyboard-focus')

    data = [@item, @itemFocus, @itemAfterFocus, @itemKeyboardFocus, @itemAfterKeyboardFocus]

    @onFocusItem = jasmine.createSpy('onFocusItem')
    @onSetCursorPosition = jasmine.createSpy('onSetCursorPosition')
    @selection = []
    @dataSource =
      selection:
        toggle: jasmine.createSpy('toggle')
        expandTo: jasmine.createSpy('expandTo')
        add: jasmine.createSpy('add')
        walk: jasmine.createSpy('walk')
        clear: jasmine.createSpy('clear')
        count: => @selection.length
        items: => @selection
        top: => @selection[-1]

      get: (idx) ->
        data[idx]
      getById: (id) ->
        _.find data, (item) -> item.id is id
      indexOfId: (id) ->
        _.findIndex data, (item) -> item.id is id
      count: -> data.length

    @props =
      dataSource: @dataSource
      keyboardCursorId: 'keyboard-focus'
      focused: @itemFocus
      focusedId: 'focus'
      onFocusItem: @onFocusItem
      onSetCursorPosition: @onSetCursorPosition

    @collection = 'threads'
    @isRootSheet = true
    @handler = new MultiselectSplitInteractionHandler(@props)

    spyOn(WorkspaceStore, 'topSheet').andCallFake => {root: @isRootSheet}

  it "should always show focus", ->
    expect(@handler.shouldShowFocus()).toEqual(true)

  it "should show the keyboard cursor when multiple items are selected", ->
    @selection = []
    expect(@handler.shouldShowKeyboardCursor()).toEqual(false)
    @selection = [@item]
    expect(@handler.shouldShowKeyboardCursor()).toEqual(false)
    @selection = [@item, @itemFocus]
    expect(@handler.shouldShowKeyboardCursor()).toEqual(true)

  describe "onClick", ->
    it "should focus the list item and indicate it was focused via click", ->
      @handler.onClick(@item)
      expect(@onFocusItem).toHaveBeenCalledWith(@item)

  describe "onMetaClick", ->
    describe "when there is currently a focused item", ->
      it "should turn the focused item into the first selected item", ->
        @handler.onMetaClick(@item)
        expect(@dataSource.selection.add).toHaveBeenCalledWith(@itemFocus)

      it "should clear the focus", ->
        @handler.onMetaClick(@item)
        expect(@onFocusItem).toHaveBeenCalledWith(null)

    it "should toggle selection", ->
      @handler.onMetaClick(@item)
      expect(@dataSource.selection.toggle).toHaveBeenCalledWith(@item)

    it "should call _checkSelectionAndFocusConsistency", ->
      spyOn(@handler, '_checkSelectionAndFocusConsistency')
      @handler.onMetaClick(@item)
      expect(@handler._checkSelectionAndFocusConsistency).toHaveBeenCalled()

  describe "onShiftClick", ->
    describe "when there is currently a focused item", ->

      it "should turn the focused item into the first selected item", ->
        @handler.onMetaClick(@item)
        expect(@dataSource.selection.add).toHaveBeenCalledWith(@itemFocus)

      it "should clear the focus", ->
        @handler.onMetaClick(@item)
        expect(@onFocusItem).toHaveBeenCalledWith(null)

    it "should expand selection", ->
      @handler.onShiftClick(@item)
      expect(@dataSource.selection.expandTo).toHaveBeenCalledWith(@item)

    it "should call _checkSelectionAndFocusConsistency", ->
      spyOn(@handler, '_checkSelectionAndFocusConsistency')
      @handler.onMetaClick(@item)
      expect(@handler._checkSelectionAndFocusConsistency).toHaveBeenCalled()

  describe "onEnter", ->

  describe "onSelect (x key on keyboard)", ->
    it "should call _checkSelectionAndFocusConsistency", ->
      spyOn(@handler, '_checkSelectionAndFocusConsistency')
      @handler.onMetaClick(@item)
      expect(@handler._checkSelectionAndFocusConsistency).toHaveBeenCalled()

  describe "onShift", ->
    it "should call _checkSelectionAndFocusConsistency", ->
      spyOn(@handler, '_checkSelectionAndFocusConsistency')
      @handler.onMetaClick(@item)
      expect(@handler._checkSelectionAndFocusConsistency).toHaveBeenCalled()

    describe "when the select option is passed", ->
      it "should turn the existing focused item into a selected item", ->
        @handler.onShift(1, {select: true})
        expect(@dataSource.selection.add).toHaveBeenCalledWith(@itemFocus)

      it "should walk the selection to the shift target", ->
        @handler.onShift(1, {select: true})
        expect(@dataSource.selection.walk).toHaveBeenCalledWith({current: @itemFocus, next: @itemAfterFocus})

    describe "when one or more items is selected", ->
      it "should move the keyboard cursor", ->
        @selection = [@itemFocus, @itemAfterFocus, @itemKeyboardFocus]
        @handler.onShift(1, {})
        expect(@onSetCursorPosition).toHaveBeenCalledWith(@itemAfterKeyboardFocus)

    describe "when no items are selected", ->
      it "should move the focus", ->
        @handler.onShift(1, {})
        expect(@onFocusItem).toHaveBeenCalledWith(@itemAfterFocus)


  describe "_checkSelectionAndFocusConsistency", ->
    describe "when only one item is selected", ->
      beforeEach ->
        @selection = [@item]
        @props.focused = null
        @handler = new MultiselectSplitInteractionHandler(@props)

      it "should clear the selection and make the item focused", ->
        @handler._checkSelectionAndFocusConsistency()
        expect(@dataSource.selection.clear).toHaveBeenCalled()
        expect(@onFocusItem).toHaveBeenCalledWith(@item)
