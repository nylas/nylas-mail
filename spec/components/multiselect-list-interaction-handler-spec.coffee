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

    @onFocusItem = jasmine.createSpy('onFocusItem')
    @onSetCursorPosition = jasmine.createSpy('onSetCursorPosition')
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

    @props =
      dataSource: @dataSource
      keyboardCursorId: 'keyboard-focus'
      focusedId: 'focus'
      onFocusItem: @onFocusItem
      onSetCursorPosition: @onSetCursorPosition

    @collection = 'threads'
    @isRootSheet = true
    @handler = new MultiselectListInteractionHandler(@props)

    spyOn(WorkspaceStore, 'topSheet').andCallFake => {root: @isRootSheet}

  it "should never show focus", ->
    expect(@handler.shouldShowFocus()).toEqual(false)

  it "should always show the keyboard cursor", ->
    expect(@handler.shouldShowKeyboardCursor()).toEqual(true)

  it "should always show checkmarks", ->
    expect(@handler.shouldShowCheckmarks()).toEqual(true)

  describe "onClick", ->
    it "should focus list items", ->
      @handler.onClick(@item)
      expect(@onFocusItem).toHaveBeenCalledWith(@item)

  describe "onMetaClick", ->
    it "shoud toggle selection", ->
      @handler.onMetaClick(@item)
      expect(@dataSource.selection.toggle).toHaveBeenCalledWith(@item)

    it "should focus the keyboard on the clicked item", ->
      @handler.onMetaClick(@item)
      expect(@onSetCursorPosition).toHaveBeenCalledWith(@item)

  describe "onShiftClick", ->
    it "should expand selection", ->
      @handler.onShiftClick(@item)
      expect(@dataSource.selection.expandTo).toHaveBeenCalledWith(@item)

    it "should focus the keyboard on the clicked item", ->
      @handler.onShiftClick(@item)
      expect(@onSetCursorPosition).toHaveBeenCalledWith(@item)

  describe "onEnter", ->
    it "should focus the item with the current keyboard selection", ->
      @handler.onEnter()
      expect(@onFocusItem).toHaveBeenCalledWith(@itemKeyboardFocus)

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
        expect(@onSetCursorPosition).toHaveBeenCalledWith(@itemAfterKeyboardFocus)

      it "should walk selection if the select option is passed", ->
        @handler.onShift(1, select: true)
        expect(@dataSource.selection.walk).toHaveBeenCalledWith({current: @itemKeyboardFocus, next: @itemAfterKeyboardFocus})

    describe "on the thread view", ->
      beforeEach ->
        @isRootSheet = false

      it "should shift the focused item", ->
        @handler.onShift(1, {})
        expect(@onFocusItem).toHaveBeenCalledWith(@itemAfterFocus)
