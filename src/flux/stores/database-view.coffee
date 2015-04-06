_ = require 'underscore-plus'
Utils = require '../models/utils'
DatabaseStore = require './database-store'
ModelView = require './model-view'
EventEmitter = require('events').EventEmitter

# DatabaseView abstracts away the process of paginating a query
# and loading ranges of data. There are a few core concepts that
# make it flexible:
#
# matchers: The where clauses that should be applied to queries.
#
# metadataProvider: For each item loaded, you can provide a promise
# that resolves with additional data for that item. The DatabaseView
# will not consider the page of data "loaded" until all the metadata
# promises have resolved.  (Used for message metadata on threads)
#
# retainedRange: The retained range ({start, end}) represents the
# objects currently being displayed. React components displaying the
# view can alter the retained range as the user scrolls.
#
# Note: Do not make the retainedRange larger than you need. The
# DatabaseView may internally keep a larger set of items loaded
# for performance.
#
#
class DatabaseView extends ModelView
  
  constructor: (@klass, config = {}, @_itemMetadataProvider) ->
    super
    @_pageSize = 100
    @_matchers = config.matchers ? []
    @_includes = config.includes ? []

    @_count = -1
    @invalidate()

    @

  itemMetadataProvider: ->
    @_itemMetadataProvider

  setItemMetadataProvider: (fn) ->
    @_itemMetadataProvider = fn
    @_pages = {}
    @invalidateRetainedRange()

  matchers: ->
    @_matchers

  setMatchers: (matchers) ->
    @_matchers = matchers
    @_pages = {}
    @_count = -1
    @invalidateRetainedRange()

  includes: ->
    @_includes

  setIncludes: (includes) ->
    @_includes = includes
    @_pages = {}
    @invalidateRetainedRange()

  # Accessing Data

  count: ->
    @_count

  padRetainedRange: ({start, end}) ->
    {start: start - @_pageSize / 2, end: end + @_pageSize / 2}

  invalidate: ({shallow} = {}) ->
    if not shallow
      for idx, page of @_pages
        page.metadata = {}

    @invalidateCount()
    @invalidateRetainedRange()

  invalidateItems: (ids = []) ->
    for idx, page of @_pages
      # remove records from page metadata
      if page.metadata
        for id in ids
          delete page.metadata[id]

    @invalidateCount()
    @invalidateRetainedRange()
  
  invalidateCount: ->
    DatabaseStore.findAll(@klass).where(@_matchers).count().then (count) =>
      @_count = count
      @_emitter.emit('trigger')

  retrievePage: (idx) ->
    start = Date.now()

    page = @_pages[idx] ? {
      metadata: {}
      items: []
    }
    page.loading = true
    @_pages[idx] = page

    query = DatabaseStore.findAll(@klass).where(@_matchers)
    query.offset(idx * @_pageSize).limit(@_pageSize)
    query.include(attr) for attr in @_includes

    query.then (items) =>
      # Now, fetch the messages for each thread. We could do this with a
      # complex join, but then we'd get thread columns repeated over and over.
      # This is reasonably fast because we don't store message bodies in messages
      # anymore.
      metadataPromises = {}
      for item in items
        if metadataPromises[item.id]
          console.log("Request for threads returned the same thread id (#{item.id}) multiple times.")

        metadataPromises[item.id] ?= page.metadata[item.id]
        if @_itemMetadataProvider
          metadataPromises[item.id] ?= @_itemMetadataProvider(item)

      Promise.props(metadataPromises).then (results) =>
        for item in items
          item.metadata = results[item.id]
          page.metadata[item.id] = results[item.id]

          # Prevent anything from mutating these objects or their nested objects.
          # Accidentally modifying items somewhere downstream (in a component)
          # can trigger awful re-renders
          Utils.modelFreeze(item)

        page.items = items
        page.loading = false
        @_emitter.emit('trigger')

        unless atom.state.mode is 'spec'
          console.log("Database view fetched #{idx} in #{Date.now() - start} msec.")

  cullPages: ->
    pagesLoaded = Object.keys(@_pages)
    pagesRetained = @pagesRetained()

    # To avoid accumulating infinite pages in memory, cull
    # any pages we've loaded that are more than 2 pages
    # away from the ones currently being retained by the view.
    first = +pagesRetained[0]
    last = +pagesRetained[pagesRetained.length - 1]

    culled = []
    for idx in pagesLoaded
      if +idx > last and +idx - last > 2
        culled.push(idx)
      else if +idx < first and first - +idx > 2
        culled.push(idx)

    @_pages = _.omit(@_pages, culled)

module.exports = DatabaseView
