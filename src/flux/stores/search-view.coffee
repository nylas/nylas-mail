_ = require 'underscore-plus'
Utils = require '../models/utils'
DatabaseStore = require './database-store'
ModelView = require './model-view'
NylasAPI = require '../nylas-api'

class SearchView extends ModelView

  constructor: (@_query, @_namespaceId) ->
    super
    @_queryResultTotal = -1
    @_querySort = 'datetime'
    _.defer => @retrievePage(0)
    @

  query: ->
    @_query

  setQuery: (query) ->
    @_query = query
    @invalidateRetainedRange()

  setSortOrder: (sort) ->
    @_querySort = sort

  # Accessing Data

  padRetainedRange: ({start, end}) ->
    # Load the next page before the view needs it by padding the "retained range" used
    # to retrieve pages.
    {start: start, end: end + 100}

  count: ->
    @_queryResultTotal

  retrievePage: (idx) ->
    start = Date.now()

    # For now, we never refresh a page we've already loaded. In the future, we may
    # want to pull existing pages from the database ala WHERE `id` IN (ids from page)
    return if @_pages[idx]

    page =
      items: []
      loading: true

    @_pages[idx] = page

    NylasAPI.makeRequest
      method: 'POST'
      path: "/n/#{@_namespaceId}/threads/search?offset=#{idx * @_pageSize}&limit=#{@_pageSize}"
      body: {"query": @_query, "sort": @_querySort}
      json: true
      returnsModel: false
      error: =>
        page.loading = false
        @_emitter.emit('trigger')
      success: (json) =>
        objects = []

        @_queryResultTotal = json.total

        for resultJSON in json.results
          obj = Utils.modelFromJSON(resultJSON.object)
          obj.relevance = resultJSON.relevance
          objects.push(obj)

        DatabaseStore.persistModels(objects) if objects.length > 0

        page.items = objects
        page.loading = false
        @_emitter.emit('trigger')

        console.log("Search view fetched #{idx} in #{Date.now() - start} msec.")


module.exports = SearchView
