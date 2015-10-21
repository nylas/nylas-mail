_ = require 'underscore'
EventEmitter = require('events').EventEmitter
ModelViewSelection = require './model-view-selection'

module.exports =
class ModelView

  constructor: ->
    @_pageSize = 100
    @_retainedRange = {start: 0, end: 50}
    @_pages = {}
    @_emitter = new EventEmitter()

    @selection = new ModelViewSelection(@, @trigger)

    @

  # Accessing Data

  trigger: =>
    return if @_triggering
    @_triggering = true
    _.defer =>
      @_triggering = false
      @_emitter.emit('trigger')

  listen: (callback, bindContext) ->
    eventHandler = (args) ->
      callback.apply(bindContext, args)
    @_emitter.addListener('trigger', eventHandler)
    return => @_emitter.removeListener('trigger', eventHandler)

  loaded: ->
    return false if @count() is -1
    for idx in @pagesRetained()
      if not @_pages[idx] or @_pages[idx].loading is true
        return false
    true

  empty: ->
    @count() <= 0

  get: (idx) ->
    unless _.isNumber(idx)
      throw new Error("ModelView.get() takes a numeric index. Maybe you meant getById()?")
    page = Math.floor(idx / @_pageSize)
    pageIdx = idx - page * @_pageSize
    @_pages[page]?.items[pageIdx] ? null

  getStub: ->
    @_sample ?= new klass

  getById: (id) ->
    return null unless id
    for pageIdx, page of @_pages
      for item, itemIdx in page.items
        return item if item.id is id
    return null

  indexOfId: (id) ->
    return -1 unless id
    for pageIdx, page of @_pages
      for item, itemIdx in page.items
        return pageIdx * @_pageSize + itemIdx if item.id is id
    return -1

  count: ->
    throw new Error("ModelView base class does not implement count()")

  pageSize: ->
    @_pageSize

  pagesRetained: ->
    [Math.floor(@_retainedRange.start / @_pageSize)..Math.floor(@_retainedRange.end / @_pageSize)]

  setRetainedRange: ({start, end}) ->
    {start, end} = @padRetainedRange({start, end})
    start = Math.max(0, Math.min(@count(), start))
    end = Math.max(0, Math.min(@count(), end))

    return if start is @_retainedRange.start and
              end is @_retainedRange.end

    @_retainedRange = {start, end}
    @retrieveDirtyInRetainedRange()
    @cullPages()

  # Optionally implement this method in subclasses to expand the retained range provided
  # by a view or listener. (For example, to fetch pages before they're needed by the view)
  padRetainedRange: ({start, end}) ->
    {start, end}

  # Optionally implement this method in subclasses to remove pages from the @_pages array
  # after the retained range has changed.
  cullPages: ->
    false

  invalidate: ({changed, shallow} = {}) ->
    # "Total Refresh" - in a subclass, do something smarter
    @invalidateRetainedRange()

  invalidateMetadataFor: ->
    # "Total Refresh" - in a subclass, do something smarter
    @invalidateRetainedRange()

  invalidateRetainedRange: ->
    for idx in @pagesRetained()
      @retrievePage(idx)

  retrieveDirtyInRetainedRange: ->
    for idx in @pagesRetained()
      if not @_pages[idx]
        @retrievePage(idx)

  retrievePage: (page) ->
    throw new Error("ModelView base class does not implement retrievePage()")
