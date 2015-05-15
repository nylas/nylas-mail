_ = require 'underscore-plus'
EventEmitter = require('events').EventEmitter
ModelView = require '../src/flux/stores/model-view'

# ModelView is an abstract base class. Basic implementation for tests

class TestModelView extends ModelView
  constructor: ->
    super
    @_pageSize = 100

  count: ->
    1000

  stubFillPage: (page) ->
    letter = ['A','B','C','D','E','F','G','H','I','J'][page]
    items = []
    items.push({id: "#{letter}#{ii}"}) for ii in [0..99]
    @_pages[page] =
      loading: false
      items: items

  retrievePage: (page) ->
    @_pages[page] =
      items: []
      loading: true
    setTimeout ->
      @stubFillPage(page)
    , 1


describe "ModelView", ->
  beforeEach ->
    @view = new TestModelView()

  describe "setRetainedRange", ->
    it "should perform basic bounds checks to avoid fetching non-existent pages", ->
      @view.setRetainedRange({start: -100, end: 15000})
      expect(@view._retainedRange).toEqual({start:0, end: @view.count()})

    it "should call the padding method to optionally expand the retained range", ->
      spyOn(@view, 'padRetainedRange').andCallFake ({start, end}) ->
        {start: start - 50, end: end + 50}
      @view.setRetainedRange({start: 0, end: 100})
      expect(@view._retainedRange).toEqual({start:0, end: 150})

    it "should retrieve pages in the range that are not cached", ->
      spyOn(@view, 'retrievePage').andCallThrough()
      @view.setRetainedRange({start: 0, end: 250})
      expect(@view.retrievePage.callCount).toBe(3)
      expect(@view.retrievePage.calls[0].args).toEqual([0])
      expect(@view.retrievePage.calls[1].args).toEqual([1])
      expect(@view.retrievePage.calls[2].args).toEqual([2])

    it "should not retrieve pages that are already cached", ->
      @view.stubFillPage(0)
      @view.stubFillPage(1)
      spyOn(@view, 'retrievePage').andCallThrough()
      @view.setRetainedRange({start: 0, end: 250})
      expect(@view.retrievePage.callCount).toBe(1)
      expect(@view.retrievePage.calls[0].args).toEqual([2])

    it "should call cullPages(), allowing subclasses to remove unneeded pages from the cache", ->
      spyOn(@view, 'cullPages')
      @view.setRetainedRange({start: 0, end: 250})
      expect(@view.cullPages).toHaveBeenCalled()

  describe "accessors", ->
    beforeEach ->
      @view.stubFillPage(0)
      @view.stubFillPage(1)

    describe "loaded", ->
      it "should return true if all of the retained pages are loaded", ->
        @view.setRetainedRange({start: 0, end: 100})
        expect(@view.loaded()).toBe(true)

      it "should return false if any retained pages are still loading", ->
        @view.setRetainedRange({start: 0, end: 300})
        expect(@view.loaded()).toBe(false)

    describe "get", ->
      it "should return the item at the index provided", ->
        expect(@view.get(12).id).toBe('A12')
        expect(@view.get(112).id).toBe('B12')

      it "should return null if the item cannot be found", ->
        expect(@view.get(12154)).toBe(null)

      it "should throw an exception if the user passes something other than an integer index", ->
        expect(( => @view.get('oops an id'))).toThrow()

    describe "getById", ->
      it "should return the item with the requested id", ->
        expect(@view.getById('A88')).toEqual({id: 'A88'})
        expect(@view.getById('B12')).toEqual({id: 'B12'})

      it "should return null if the item cannot be found", ->
        expect(@view.getById('E12')).toEqual(null)

      it "should return null if no id is provided", ->
        expect(@view.getById(undefined)).toEqual(null)

    describe "indexOfId", ->
      it "should return the index of the item with the id", ->
        expect(@view.indexOfId('A88')).toEqual(88)
        expect(@view.indexOfId('B12')).toEqual(100 * 1 + 12)

      it "should return -1 if the item cannot be found", ->
        expect(@view.indexOfId('E12')).toEqual(-1)

      it "should return -1 if no id is provided", ->
        expect(@view.indexOfId(undefined)).toEqual(-1)

    describe "pagesRetained", ->
      it "should return an array of page indexes currently being maintained", ->
        @view._retainedRange = {start: 0, end: 99}
        expect(@view.pagesRetained()).toEqual([0])
        @view._retainedRange = {start: 0, end: 340}
        expect(@view.pagesRetained()).toEqual([0..3])
        @view._retainedRange = {start: 900, end: 999}
        expect(@view.pagesRetained()).toEqual([9])

    describe "invalidateRetainedRange", ->
      it "should initiate requests for all the pages in the retained range", ->
        spyOn(@view, 'retrievePage')
        @view._retainedRange = {start: 0, end: 340}
        @view.invalidateRetainedRange()
        expect(@view.retrievePage.callCount).toBe(4)
        for i in [0..3]
          expect(@view.retrievePage.calls[i].args).toEqual([i])
