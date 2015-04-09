_ = require 'underscore-plus'
Utils = require '../models/utils'
DatabaseStore = require './database-store'
ModelView = require './model-view'
EventEmitter = require('events').EventEmitter

# DatabaseView abstracts away the process of paginating a query
# and loading ranges of data. It's very smart about deciding when
# results need to be refreshed. There are a few core concepts that
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

verbose = true

class DatabaseView extends ModelView
  
  constructor: (@klass, config = {}, @_itemMetadataProvider) ->
    super
    @_pageSize = 100
    @_matchers = config.matchers ? []
    @_includes = config.includes ? []

    @_count = -1
    @invalidate()

    @

  log: ->
    return unless verbose and not atom.inSpecMode()
    if _.isString(arguments[0])
      arguments[0] = "DatabaseView (#{@klass.name}): "+arguments[0]
    console.log(arguments...)

  itemMetadataProvider: ->
    @_itemMetadataProvider

  setItemMetadataProvider: (fn) ->
    @_itemMetadataProvider = fn
    @_pages = {}
    @invalidate()

  matchers: ->
    @_matchers

  setMatchers: (matchers) ->
    @_matchers = matchers
    @_pages = {}
    @_count = -1
    @invalidate()

  includes: ->
    @_includes

  setIncludes: (includes) ->
    @_includes = includes
    @_pages = {}
    @invalidate()

  # Accessing Data

  count: ->
    @_count

  padRetainedRange: ({start, end}) ->
    {start: start - @_pageSize / 2, end: end + @_pageSize / 2}

  invalidate: ({shallow, changed} = {}) ->
    if shallow and changed
      @invalidateIfItemsInconsistent(changed)
    else if shallow
      @invalidateCount()
      @invalidateRetainedRange()
    else
      @log('Invalidating entire range and all metadata.')
      for idx, page of @_pages
        page.metadata = {}
      @invalidateCount()
      @invalidateRetainedRange()
  
  invalidateIfItemsInconsistent: (items) ->
    if items.length is 0
      return

    if items.length > 5
      @log('invalidateIfItemsInconsistent on '+items.length+'items would be expensive. Invalidating entire range.')
      @invalidateCount()
      @invalidateRetainedRange()
      return

    pagesCouldHaveChanged = false
    didMakeOptimisticChange = false
    sortAttribute = items[0].constructor.naturalSortOrder()?.attribute()
    indexes = []

    spliceItem = (idx) =>
      page = Math.floor(idx / @_pageSize)
      pageIdx = idx - page * @_pageSize

      # Remove the item in question from the page
      @_pages[page]?.items.splice(pageIdx, 1)

      # Iterate through the remaining pages. Take the first
      # item from the next page, remove it, and put it at the
      # end of our page (to fill the space left by splice above.)
      while @_pages[page + 1] and @_pages[page + 1].loading is false
        item = @_pages[page + 1].items[0]
        @_pages[page + 1].items.splice(0, 1)
        @_pages[page].items.push(item)
        page += 1

      didMakeOptimisticChange = true

    for item in items
      idx = @indexOfId(item.id)
      indexes.push(idx)

      # The item matches our set but isn't in our items array
      if item.matches(@_matchers) and idx is -1
        @log("Item matches criteria but not found in cached set. Invalidating entire range.")
        pagesCouldHaveChanged = true

      # The item does not match our set, but is in our items array
      else if idx isnt -1 and not item.matches(@_matchers)
        @log("Item does not match criteria but is in cached set. Invalidating entire range.")
        pagesCouldHaveChanged = true

        # Remove the item and fire immediately. This means the user will see the item
        # disappear, and then after the new page comes in the content could change, but
        # they get immediate feedback.
        spliceItem(idx)

      # The value of the item's sort attribute has changed, and we don't
      # know if it will be in the same position in a new page.
      else if idx isnt -1 and sortAttribute
        existing = @get(idx)
        existingSortValue = existing[sortAttribute.modelKey]
        itemSortValue = item[sortAttribute.modelKey]

        # http://stackoverflow.com/questions/4587060/determining-date-equality-in-javascript
        if not (existingSortValue >= itemSortValue && existingSortValue <= itemSortValue)
          @log("Item sort value has changed (#{itemSortValue} != #{existingSortValue}). Invalidating entire range.")
          pagesCouldHaveChanged = true

    if didMakeOptimisticChange
      @_emitter.emit('trigger')

    if pagesCouldHaveChanged
      @invalidateCount()
      @invalidateRetainedRange()
    else
      # No items have changed membership in our set. Just go through and
      # replace all the old items with the new versions, and avoid all
      # database queries. (!)
      #
      # NOTE: This code assumes sort order of items in the set never changes.
      # May need to perform sort or extend above code to check particular sort
      # fields for any changes.
      #
      @log("Items being swapped in place, page membership has not changed.", items)

      for item, ii in items
        idx = indexes[ii]
        continue if idx is -1
        page = Math.floor(idx / @_pageSize)
        pageIdx = idx - page * @_pageSize

        # Always copy the item so that a deep equals is never necessary
        item = new @klass(item)
        item.metadata = @_pages[page]?.metadata[item.id]
        @_pages[page]?.items[pageIdx] = item

      @selection.updateModelReferences(items)
      @_emitter.emit('trigger')


  invalidateMetadataFor: (ids = []) ->
    # This method should be called when you know that only the metadata for
    # a given set of items has been dirtied. For example, when we have a view
    # of Threads and their Messages change.

    # This method only performs the metadata loading step and only re-fetches
    # metadata for the items whose ids are provided.

    for idx, page of @_pages
      dirtied = false
      if page.metadata
        for id in ids
          if page.metadata[id]
            delete page.metadata[id]
            dirtied = true
      if dirtied
        @log('Invalidated metadata for items with ids: '+JSON.stringify(ids))
        @retrievePageMetadata(idx, page.items)

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

    page.loadingStart = start
    page.loading = true
    @_pages[idx] = page

    query = DatabaseStore.findAll(@klass).where(@_matchers)
    query.offset(idx * @_pageSize).limit(@_pageSize)
    query.include(attr) for attr in @_includes

    query.then (items) =>
      # If we've started reloading since we made our query, don't do any more work
      if page.loadingStart isnt start
        return

      # Now, fetch the messages for each thread. We could do this with a
      # complex join, but then we'd get thread columns repeated over and over.
      # This is reasonably fast because we don't store message bodies in messages
      # anymore.
      @retrievePageMetadata(idx, items)

  retrievePageMetadata: (idx, items) ->
    page = @_pages[idx]

    # This method can only be used once the page is loaded. If no page is present,
    # go ahead and retrieve it in full.
    if not page
      @retrievePage(idx)
      return

    metadataPromises = {}
    for item in items
      if metadataPromises[item.id]
        @log("Request for threads returned the same thread id (#{item.id}) multiple times.")

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

      @selection.updateModelReferences(items)

      page.items = items
      page.loading = false
      
      # Trigger if this is the last page that needed to be loaded
      @_emitter.emit('trigger') if @loaded()

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
