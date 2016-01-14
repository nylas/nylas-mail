MultiselectListInteractionHandler = require '../../src/components/multiselect-list-interaction-handler'
WorkspaceStore = require '../../src/flux/stores/workspace-store'
FocusedContentStore = require '../../src/flux/stores/focused-content-store'
Thread = require '../../src/flux/models/thread'
Actions = require '../../src/flux/actions'
_ = require 'underscore'

describe "MultiselectListInteractionHandler", ->
  beforeEach ->
    @item = new Thread(id:'123')
    @itemFocus = new Thread({id: 'focus'})
    @itemKeyboardFocus = new Thread({id: 'keyboard-focus'})
    @itemAfterFocus = new Thread(id:'after-focus')
    @itemAfterKeyboardFocus = new Thread(id:'after-keyboard-focus')

    data = [@item, @itemFocus, @itemAfterFocus, @itemKeyboardFocus, @itemAfterKeyboardFocus]

    @dataSource =
      selection:
        toggle: jasmine.createSpy('toggle')
        expandTo: jasmine.createSpy('expandTo')
        walk: jasmine.createSpy('walk')
      get: (idx) ->
        data[idx]
      getById: (id) ->
        _.find data, (item) -> item.id is id
      indexOfId: (id) ->
        _.findIndex data, (item) -> item.id is id
      count: -> data.length

    @collection = 'threads'
    @handler = new MultiselectListInteractionHandler(@dataSource, @collection)
    @isRootSheet = true

    spyOn(WorkspaceStore, 'topSheet').andCallFake => {root: @isRootSheet}
    spyOn(FocusedContentStore, 'keyboardCursorId').andCallFake -> 'keyboard-focus'
    spyOn(FocusedContentStore, 'focusedId').andCallFake -> 'focus'
    spyOn(Actions, 'setFocus')
    spyOn(Actions, 'setCursorPosition')

  it "should never show focus", ->
    expect(@handler.shouldShowFocus()).toEqual(false)

  it "should always show the keyboard cursor", ->
    expect(@handler.shouldShowKeyboardCursor()).toEqual(true)

  describe "onClick", ->
    it "should focus list items", ->
      @handler.onClick(@item)
      expect(Actions.setFocus).toHaveBeenCalledWith({collection: @collection, item: @item})

  describe "onMetaClick", ->
    it "shoud toggle selection", ->
      @handler.onMetaClick(@item)
      expect(@dataSource.selection.toggle).toHaveBeenCalledWith(@item)

    it "should focus the keyboard on the clicked item", ->
      @handler.onMetaClick(@item)
      expect(Actions.setCursorPosition).toHaveBeenCalledWith({collection: @collection, item: @item})

  describe "onShiftClick", ->
    it "should expand selection", ->
      @handler.onShiftClick(@item)
      expect(@dataSource.selection.expandTo).toHaveBeenCalledWith(@item)

    it "should focus the keyboard on the clicked item", ->
      @handler.onShiftClick(@item)
      expect(Actions.setCursorPosition).toHaveBeenCalledWith({collection: @collection, item: @item})

  describe "onEnter", ->
    it "should focus the item with the current keyboard selection", ->
      @handler.onEnter()
      expect(Actions.setFocus).toHaveBeenCalledWith({collection: @collection, item: @itemKeyboardFocus})

  describe "onSelect (x key on keyboard)", ->
    describe "on the root view", ->
      it "should toggle the selection of the keyboard item", ->
        @isRootSheet = true
        @handler.onSelect()
        expect(@dataSource.selection.toggle).toHaveBeenCalledWith(@itemKeyboardFocus)

    describe "on the thread view", ->
      it "should toggle the selection of the focused item", ->
        @isRootSheet = false
        @handler.onSelect()
        expect(@dataSource.selection.toggle).toHaveBeenCalledWith(@itemFocus)

  describe "onShift", ->
    describe "on the root view", ->
      beforeEach ->
        @isRootSheet = true

      it "should shift the keyboard item", ->
        @handler.onShift(1, {})
        expect(Actions.setCursorPosition).toHaveBeenCalledWith({collection: @collection, item: @itemAfterKeyboardFocus})

      it "should walk selection if the select option is passed", ->
        @handler.onShift(1, select: true)
        expect(@dataSource.selection.walk).toHaveBeenCalledWith({current: @itemKeyboardFocus, next: @itemAfterKeyboardFocus})

    describe "on the thread view", ->
      beforeEach ->
        @isRootSheet = false

      it "should shift the focused item", ->
        @handler.onShift(1, {})
        expect(Actions.setFocus).toHaveBeenCalledWith({collection: @collection, item: @itemAfterFocus})
