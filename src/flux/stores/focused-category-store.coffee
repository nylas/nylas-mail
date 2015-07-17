NylasStore = require 'nylas-store'
CategoryStore = require './category-store'
NamespaceStore = require './namespace-store'
Actions = require '../actions'

class FocusedCategoryStore extends NylasStore
  constructor: ->
    @listenTo CategoryStore, @_onCategoryStoreChanged
    @listenTo NamespaceStore, @_setDefaultCategory
    @listenTo Actions.focusCategory, @_onFocusCategory
    @listenTo Actions.searchQueryCommitted, @_onSearchQueryCommitted
    @_setDefaultCategory()

  # Inbound Events
  _onCategoryStoreChanged: ->
    if @_category?.id
      category = CategoryStore.byId(@_category.id)
      @_setCategory(category)
    else
      @_setDefaultCategory()

  _setDefaultCategory: ->
    @_category = null
    @_setCategory(CategoryStore.getStandardCategory('inbox'))

  _onFocusCategory: (category) ->
    return if @_category?.id is category?.id

    if @_category is null and category
      Actions.searchQueryCommitted('')

    @_setCategory(category)

  _onSearchQueryCommitted: (query="") ->
    if typeof(query) != "string"
      query = query[0].all
    if query.trim().length > 0 and @_category
      @_categoryBeforeSearch = @_category
      @_setCategory(null)
    else if query.trim().length is 0
      if @_categoryBeforeSearch
        @_setCategory(@_categoryBeforeSearch)
      else
        @_setDefaultCategory()

  _setCategory: (category) ->
    return if @_category?.id is category?.id
    @_category = category
    @trigger()

  # Public Methods

  category: -> @_category ? null

  categoryId: -> @_category?.id ? null

  categoryName: -> @_category?.name ? null

module.exports = new FocusedCategoryStore()
