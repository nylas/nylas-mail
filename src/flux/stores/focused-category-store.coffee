NylasStore = require 'nylas-store'
CategoryStore = require './category-store'
AccountStore = require './account-store'
Actions = require '../actions'

class FocusedCategoryStore extends NylasStore
  constructor: ->
    @listenTo CategoryStore, @_onCategoryStoreChanged
    @listenTo Actions.focusCategory, @_onFocusCategory
    @listenTo Actions.searchQueryCommitted, @_onSearchQueryCommitted
    @_onCategoryStoreChanged()

  # Inbound Events
  _onCategoryStoreChanged: ->
    if @_category?.id
      category = CategoryStore.byId(@_category.id)
    category ?= @_defaultCategory()
    @_setCategory(category)

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
        @_setCategory(@_defaultCategory())

  _defaultCategory: ->
    CategoryStore.getStandardCategory('inbox')

  _setCategory: (category) ->
    return if @_category?.id is category?.id
    @_category = category
    @trigger()

  # Public Methods

  category: -> @_category ? null

  categoryId: -> @_category?.id ? null

  categoryName: -> @_category?.name ? null

module.exports = new FocusedCategoryStore()
