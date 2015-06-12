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
    @selection = []
    @dataView =
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

    @collection = 'threads'
    @handler = new MultiselectSplitInteractionHandler(@dataView, @collection)
    @isRootSheet = true

    spyOn(WorkspaceStore, 'topSheet').andCallFake => {root: @isRootSheet}
    spyOn(Actions, 'setFocus')
    spyOn(Actions, 'setCursorPosition')

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
    it "should focus list items", ->
      @handler.onClick(@item)
      expect(Actions.setFocus).toHaveBeenCalledWith({collection: @collection, item: @item})

  describe "onMetaClick", ->
    describe "when there is currently a focused item", ->
      beforeEach ->
        spyOn(FocusedContentStore, 'focused').andCallFake => @itemFocus
        spyOn(FocusedContentStore, 'focusedId').andCallFake -> 'focus'

      it "should turn the focused item into the first selected item", ->
        @handler.onMetaClick(@item)
        expect(@dataView.selection.add).toHaveBeenCalledWith(@itemFocus)

      it "should clear the focus", ->
        @handler.onMetaClick(@item)
        expect(Actions.setFocus).toHaveBeenCalledWith({collection: @collection, item: null})

    it "should toggle selection", ->
      @handler.onMetaClick(@item)
      expect(@dataView.selection.toggle).toHaveBeenCalledWith(@item)

    it "should call _checkSelectionAndFocusConsistency", ->
      spyOn(@handler, '_checkSelectionAndFocusConsistency')
      @handler.onMetaClick(@item)
      expect(@handler._checkSelectionAndFocusConsistency).toHaveBeenCalled()

  describe "onShiftClick", ->
    describe "when there is currently a focused item", ->
      beforeEach ->
        spyOn(FocusedContentStore, 'focused').andCallFake => @itemFocus
        spyOn(FocusedContentStore, 'focusedId').andCallFake -> 'focus'

      it "should turn the focused item into the first selected item", ->
        @handler.onMetaClick(@item)
        expect(@dataView.selection.add).toHaveBeenCalledWith(@itemFocus)

      it "should clear the focus", ->
        @handler.onMetaClick(@item)
        expect(Actions.setFocus).toHaveBeenCalledWith({collection: @collection, item: null})

    it "should expand selection", ->
      @handler.onShiftClick(@item)
      expect(@dataView.selection.expandTo).toHaveBeenCalledWith(@item)

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
        spyOn(FocusedContentStore, 'focused').andCallFake => @itemFocus
        spyOn(FocusedContentStore, 'focusedId').andCallFake -> 'focus'
        @handler.onShift(1, {select: true})
        expect(@dataView.selection.add).toHaveBeenCalledWith(@itemFocus)

      it "should walk the selection to the shift target", ->
        spyOn(FocusedContentStore, 'focused').andCallFake => @itemFocus
        spyOn(FocusedContentStore, 'focusedId').andCallFake -> 'focus'
        @handler.onShift(1, {select: true})
        expect(@dataView.selection.walk).toHaveBeenCalledWith({current: @itemFocus, next: @itemAfterFocus})

    describe "when one or more items is selected", ->
      it "should move the keyboard cursor", ->
        @selection = [@itemFocus, @itemAfterFocus, @itemKeyboardFocus]
        spyOn(FocusedContentStore, 'keyboardCursor').andCallFake => @itemKeyboardFocus
        spyOn(FocusedContentStore, 'keyboardCursorId').andCallFake -> 'keyboard-focus'
        @handler.onShift(1, {})
        expect(Actions.setCursorPosition).toHaveBeenCalledWith({collection: @collection, item: @itemAfterKeyboardFocus})

    describe "when no items are selected", ->
      it "should move the focus", ->
        spyOn(FocusedContentStore, 'focused').andCallFake => @itemFocus
        spyOn(FocusedContentStore, 'focusedId').andCallFake -> 'focus'
        @handler.onShift(1, {})
        expect(Actions.setFocus).toHaveBeenCalledWith({collection: @collection, item: @itemAfterFocus})


  describe "_checkSelectionAndFocusConsistency", ->
    describe "when only one item is selected", ->
      beforeEach ->
        spyOn(FocusedContentStore, 'focused').andCallFake -> null
        spyOn(FocusedContentStore, 'focusedId').andCallFake -> null
        @selection = [@item]

      it "should clear the selection and make the item focused", ->
        @handler._checkSelectionAndFocusConsistency()
        expect(@dataView.selection.clear).toHaveBeenCalled()
        expect(Actions.setFocus).toHaveBeenCalledWith({collection: @collection, item: @item})
