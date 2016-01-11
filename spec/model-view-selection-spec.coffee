_ = require 'underscore'

Thread = require '../src/flux/models/thread'
ModelView = require '../src/flux/stores/model-view'
ModelViewSelection = require '../src/flux/stores/model-view-selection'

describe "ModelViewSelection", ->
  beforeEach ->
    @trigger = jasmine.createSpy('trigger')

    @items = []
    @items.push(new Thread(id: "#{ii}")) for ii in [0..99]

    @view = new ModelView()
    @view.indexOfId = jasmine.createSpy('indexOfId').andCallFake (id) =>
      _.findIndex(@items, _.matcher({id}))
    @view.get = jasmine.createSpy('get').andCallFake (idx) =>
      @items[idx]

    @selection = new ModelViewSelection(@view, @trigger)

  it "should initialize with an empty set", ->
    expect(@selection.items()).toEqual([])
    expect(@selection.ids()).toEqual([])

  it "should throw an exception if a view is not provided", ->
    expect( => new ModelViewSelection(null, @trigger)).toThrow()

  describe "set", ->
    it "should replace the current selection with the provided models", ->
      @selection.set([@items[2], @items[4], @items[7]])
      expect(@selection.ids()).toEqual(['2', '4', '7'])
      @selection.set([@items[2], @items[5], @items[6]])
      expect(@selection.ids()).toEqual(['2', '5', '6'])

    it "should throw an exception if the items passed are not models", ->
      expect( => @selection.set(['hi'])).toThrow()

    it "should trigger", ->
      @selection.set([@items[2], @items[4], @items[7]])
      expect(@trigger).toHaveBeenCalled()

  describe "clear", ->
    beforeEach ->
      @selection.set([@items[2]])

    it "should empty the selection set", ->
      @selection.clear()
      expect(@selection.ids()).toEqual([])

    it "should trigger", ->
      @selection.clear()
      expect(@trigger).toHaveBeenCalled()

  describe "remove", ->
    beforeEach ->
      @selection.set([@items[2], @items[4]])

    it "should do nothing if called without a valid item", ->
      @selection.remove(null)
      @selection.remove(undefined)
      @selection.remove(false)
      expect(@selection.ids()).toEqual(['2', '4'])

    it "should remove the item from the set", ->
      @selection.remove(@items[2])
      expect(@selection.ids()).toEqual(['4'])

    it "should throw an exception if the item passed is not a model", ->
      expect( => @selection.remove('hi')).toThrow()

    it "should trigger", ->
      @selection.remove()
      expect(@trigger).toHaveBeenCalled()

  describe "updateModelReferences", ->
    it "should replace items in the selection with the matching provided items, if present", ->
      @selection.set([@items[2], @items[4], @items[7]])
      expect(@selection.items()[0]).toBe(@items[2])

      expect(@selection.items()[0].subject).toBe(undefined)
      newItem2 = new Thread(id: '2', subject:'Hello world!')
      @selection.updateModelReferences([newItem2])
      expect(@selection.items()[0].subject).toBe('Hello world!')

  describe "toggle", ->
    beforeEach ->
      @selection.set([@items[2]])

    it "should do nothing if called without a valid item", ->
      @selection.toggle(null)
      @selection.toggle(undefined)
      @selection.toggle(false)
      expect(@selection.ids()).toEqual(['2'])

    it "should throw an exception if the item passed is not a model", ->
      expect( => @selection.toggle('hi')).toThrow()

    it "should select the item if it is not selected", ->
      @selection.toggle(@items[3])
      expect(@selection.ids()).toEqual(['2', '3'])

    it "should de-select the item if it is selected", ->
      @selection.toggle(@items[2])
      expect(@selection.ids()).toEqual([])

    it "should trigger", ->
      @selection.toggle(@items[2])
      expect(@trigger).toHaveBeenCalled()

  describe "expandTo", ->
    it "should select the item, if no other items are selected", ->
      @selection.clear()
      @selection.expandTo(@items[2])
      expect(@selection.ids()).toEqual(['2'])

    it "should do nothing if called without a valid item", ->
      @selection.expandTo(null)
      @selection.expandTo(undefined)
      @selection.expandTo(false)
      expect(@selection.ids()).toEqual([])

    it "should throw an exception if the item passed is not a model", ->
      expect( => @selection.expandTo('hi')).toThrow()

    it "should select all items from the last selected item to the provided item", ->
      @selection.set([@items[2], @items[5]])
      @selection.expandTo(@items[8])
      expect(@selection.ids()).toEqual(['2','5','6','7','8'])

    it "should not do anything if the provided item is not in the view set", ->
      @selection.set([@items[2]])
      @selection.expandTo(new Thread(id:'not-in-view!'))
      expect(@selection.ids()).toEqual(['2'])

    it "should re-order items so that the order still reflects the order selection actions were taken", ->
      @selection.set([@items[10], @items[4], @items[1]])
      @selection.expandTo(@items[8])
      expect(@selection.ids()).toEqual(['10','1','2','3','4','5','6','7','8'])

    it "should trigger", ->
      @selection.set([@items[5], @items[4], @items[1]])
      @selection.expandTo(@items[8])
      expect(@trigger).toHaveBeenCalled()

  describe "walk", ->
    beforeEach ->
      @selection.set([@items[2]])

    it "should trigger", ->
      current = @items[4]
      next = @items[5]
      @selection.walk({current, next})
      expect(@trigger).toHaveBeenCalled()

    it "should select both items if neither the start row or the end row are selected", ->
      current = @items[4]
      next = @items[5]
      @selection.walk({current, next})
      expect(@selection.ids()).toEqual(['2', '4', '5'])

    it "should select only one item if either current or next is null or undefined", ->
      current = null
      next = @items[5]
      @selection.walk({current, next})
      expect(@selection.ids()).toEqual(['2', '5'])

      next = null
      current = @items[7]
      @selection.walk({current, next})
      expect(@selection.ids()).toEqual(['2', '5', '7'])

    describe "when the `next` item is a step backwards in the selection history", ->
      it "should deselect the current item", ->
        @selection.set([@items[2], @items[3], @items[4], @items[5]])
        current = @items[5]
        next = @items[4]
        @selection.walk({current, next})
        expect(@selection.ids()).toEqual(['2', '3', '4'])

    describe "otherwise", ->
      it "should select the next item", ->
        @selection.set([@items[2], @items[3], @items[4], @items[5]])
        current = @items[5]
        next = @items[6]
        @selection.walk({current, next})
        expect(@selection.ids()).toEqual(['2', '3', '4', '5', '6'])

      describe "if the item was already selected", ->
        it "should re-order the selection array so the selection still represents selection history", ->
          @selection.set([@items[5], @items[8], @items[7], @items[6]])
          expect(@selection.ids()).toEqual(['5', '8', '7', '6'])

          current = @items[6]
          next = @items[5]
          @selection.walk({current, next})
          expect(@selection.ids()).toEqual(['8', '7', '6', '5'])
