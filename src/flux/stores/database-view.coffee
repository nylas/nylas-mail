_ = require 'underscore'
Utils = require '../models/utils'
DatabaseStore = require './database-store'
ModelView = require './model-view'
EventEmitter = require('events').EventEmitter

verbose = false

# A small helper class that prevents the DatabaseView from making too many
# queries. It tracks the number of jobs in flight via `increment` and allows
# a callback to run "when there are fewer then N ongoing queries".
# Sort of like _.throttle, but with a work threshold rather than a time threshold.
class TaskThrottler
  constructor: (@_maxConcurrent) ->
    @_inflight = 0
    @_whenReady = null

  whenReady: (fn) ->
    if @_inflight < @_maxConcurrent
      fn()
    else
      @_whenReady = fn

  increment: ->
    decremented = false
    @_inflight += 1

    # Returns a function that can be called once and only once to
    # decrement the counter.
    return =>
      if not decremented
        @_inflight -= 1
        if @_whenReady and @_inflight < @_maxConcurrent
          @_whenReady()
          @_whenReady = null
      decremented = true


# Public: DatabaseView abstracts away the process of paginating a query
# and loading ranges of data. It's very smart about deciding when
# results need to be refreshed. There are a few core concepts that
# make it flexible:
#
# - `matchers`: The where clauses that should be applied to queries.
# - `includes`: The include clauses that should be applied to queries.
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
# Section: Database
#
class DatabaseView extends ModelView

  constructor: (@klass, config = {}, @_metadataProvider) ->
    super
    @_pageSize = 100
    @_throttler = new TaskThrottler(2)

    @_matchers = config.matchers ? []
    @_includes = config.includes ? []
    @_orders = config.orders ? []

    @_count = -1
    process.nextTick =>
      @invalidateCount()
      @invalidateRetainedRange()
    @

  log: ->
    return unless verbose and not NylasEnv.inSpecMode()
    if _.isString(arguments[0])
      arguments[0] = "DatabaseView (#{@klass.name}): "+arguments[0]
    console.log(arguments...)

  metadataProvider: ->
    @_metadataProvider

  setMetadataProvider: (fn) ->
    @_metadataProvider = fn
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

  orders: ->
    @_orders

  setOrders: (orders) ->
    @_orders = orders
    @_pages = {}
    @invalidate()

  # Accessing Data

  count: ->
    @_count

  padRetainedRange: ({start, end}) ->
    {start: start - @_pageSize / 2, end: end + @_pageSize / 2}

  # Public: Call this method when the DatabaseStore triggers and will impact the
  # data maintained by this DatabaseView. In the future, the DatabaseView will
  # probably observe the DatabaseView directly.
  #
  # - `options` an Object with the following optional keys which can be used to
  #   optimize the behavior of the DatabaseView:
  #     - `change`: The change object provided by the DatabaseStore, with `items` and a `type`.
  #     - `shallow`: True if this change will not invalidate item metadata, only items.
  #
  # TODO: In order for the DatabaseView to monitor the DatabaseStore directly,
  # it needs to have some way of detatching it's listener when it's no longer needed!
  # Need a destructor...
  #
  invalidate: ({shallow, change} = {}) ->
    if shallow and change
      @invalidateAfterDatabaseChange(change)
    else if shallow
      @invalidateCount()
      @invalidateRetainedRange()
    else
      @log('Invalidating entire range and all metadata.')
      for idx, page of @_pages
        page.metadata = {}
      @invalidateCount()
      @invalidateRetainedRange()

  invalidateAfterDatabaseChange: (change) ->
    items = change.objects

    if items.length is 0
      return

    @selection.updateModelReferences(items)
    @selection.removeItemsNotMatching(@_matchers)
    if change.type is 'unpersist'
      @selection.remove(item) for item in items

    if items.length > 5
      @log("invalidateAfterDatabaseChange on #{items.length} items would be expensive. Invalidating entire range.")
      @invalidateCount()
      @invalidateRetainedRange()
      return

    pagesCouldHaveChanged = false
    didMakeOptimisticChange = false
    sortAttribute = items[0].constructor.naturalSortOrder()?.attribute()
    indexes = []

    touchTime = Date.now()

    spliceItem = (idx) =>
      page = Math.floor(idx / @_pageSize)
      pageIdx = idx - page * @_pageSize

      # Remove the item in question from the page
      @_pages[page]?.items.splice(pageIdx, 1)

      # Update the page's `lastTouchTime`. This causes pending refreshes
      # of page data to be cancelled. This is important because these refreshes
      # would actually roll back this optimistic change.
      @_pages[page]?.lastTouchTime = touchTime

      # Iterate through the remaining pages. Take the first
      # item from the next page, remove it, and put it at the
      # end of our page (to fill the space left by splice above.)
      while @_pages[page + 1] and @_pages[page + 1].items
        item = @_pages[page + 1].items[0]
        break unless item
        @_pages[page + 1].items.splice(0, 1)
        @_pages[page + 1].lastTouchTime = touchTime
        @_pages[page].items.push(item)
        page += 1

      didMakeOptimisticChange = true

    for item in items
      idx = @indexOfId(item.id)
      itemIsInSet = idx isnt -1
      itemShouldBeInSet = item.matches(@_matchers) and change.type isnt 'unpersist'
      indexes.push(idx)

      # The item matches our set but isn't in our items array
      if not itemIsInSet and itemShouldBeInSet
        @log("Item matches criteria but not found in cached set. Invalidating entire range.")
        pagesCouldHaveChanged = true

      # The item does not match our set, but is in our items array
      else if itemIsInSet and not itemShouldBeInSet
        @log("Item does not match criteria but is in cached set. Invalidating entire range.")
        pagesCouldHaveChanged = true

        # Remove the item and fire immediately. This means the user will see the item
        # disappear, and then after the new page comes in the content could change, but
        # they get immediate feedback.
        spliceItem(idx)

      # The value of the item's sort attribute has changed, and we don't
      # know if it will be in the same position in a new page.
      else if itemIsInSet and sortAttribute
        existing = @get(idx)
        existingSortValue = existing[sortAttribute.modelKey]
        itemSortValue = item[sortAttribute.modelKey]

        # http://stackoverflow.com/questions/4587060/determining-date-equality-in-javascript
        if not (existingSortValue >= itemSortValue && existingSortValue <= itemSortValue)
          @log("Item sort value has changed (#{itemSortValue} != #{existingSortValue}). Invalidating entire range.")
          pagesCouldHaveChanged = true

    if didMakeOptimisticChange
      @trigger()

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

      @trigger()

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
        if ids.length < 5
          @log("Invalidated metadata for items with ids: #{JSON.stringify(ids)}")
        else
          @log("Invalidated metadata for #{ids.length} items")
        @retrievePageMetadata(idx, page.items)

  invalidateCount: ->
    DatabaseStore.findAll(@klass).where(@_matchers).count().then (count) =>
      @_count = count
      @trigger()

  invalidateRetainedRange: ->
    @_throttler.whenReady =>
      for idx in @pagesRetained()
        @retrievePage(idx)

  retrieveDirtyInRetainedRange: ->
    @_throttler.whenReady =>
      for idx in @pagesRetained()
        if not @_pages[idx] or @_pages[idx].lastTouchTime > @_pages[idx].lastLoadTime
          @retrievePage(idx)

  retrievePage: (idx) ->
    page = @_pages[idx] ? {
      lastTouchTime: 0
      lastLoadTime: 0
      metadata: {}
      items: []
    }

    page.loading = true
    @_pages[idx] = page

    # Even though we won't touch the items array for another 100msec, the data
    # will reflect "now" since we make the query now.
    touchTime = Date.now()

    query = DatabaseStore.findAll(@klass).where(@_matchers)
    query.offset(idx * @_pageSize).limit(@_pageSize)
    query.include(attr) for attr in @_includes
    query.order(@_orders) if @_orders.length > 0

    decrement = @_throttler.increment()
    query.run().finally(decrement).then (items) =>
      # If the page is no longer in the cache at all, it may have fallen out of the
      # retained range and been cleaned up.
      return unless @_pages[idx]

      # The data has been changed and is now "newer" than our query result. Applying
      # our version of the items would roll it back. Abort!
      if page.lastTouchTime >= touchTime
        @log("Version #{touchTime} fetched, but out of date (current is #{page.lastTouchTime})")
        return

      # Now, fetch the messages for each thread. We could do this with a
      # complex join, but then we'd get thread columns repeated over and over.
      # This is reasonably fast because we don't store message bodies in messages
      # anymore.
      @retrievePageMetadata(idx, items)

  retrievePageMetadata: (idx, items) ->
    page = @_pages[idx]

    # Even though we won't touch the items array for another 100msec, the data
    # will reflect "now" since we make the query now.
    touchTime = Date.now()

    # This method can only be used once the page is loaded. If no page is present,
    # go ahead and retrieve it in full.
    if not page
      @retrievePage(idx)
      return

    idsMissingMetadata = []
    for item in items
      if not page.metadata[item.id]
        idsMissingMetadata.push(item.id)

    metadataPromise = Promise.resolve({})
    if idsMissingMetadata.length > 0 and @_metadataProvider
      metadataPromise = @_metadataProvider(idsMissingMetadata)

    decrement = @_throttler.increment()
    metadataPromise.finally(decrement).then (results) =>
      # If we've started reloading since we made our query, don't do any more work
      if page.lastTouchTime >= touchTime
        @log("Metadata version #{touchTime} fetched, but out of date (current is #{page.lastTouchTime})")
        return

      for item, idx in items
        if Object.isFrozen(item)
          item = items[idx] = new @klass(item)
        metadata = results[item.id] ? page.metadata[item.id]
        item.metadata = page.metadata[item.id] = metadata

        # Prevent anything from mutating these objects or their nested objects.
        # Accidentally modifying items somewhere downstream (in a component)
        # can trigger awful re-renders
        Utils.modelFreeze(item)

      @selection.updateModelReferences(items)
      @selection.removeItemsNotMatching(@_matchers)

      page.items = items
      page.loading = false
      page.lastLoadTime = touchTime
      page.lastTouchTime = touchTime

      # Trigger if this is the last page that needed to be loaded
      @trigger() if @loaded()

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
