_ = require 'underscore'

Model = require '../flux/models/model'
DatabaseStore = require '../flux/stores/database-store'

module.exports =
class ListSelection

  constructor: (@_view, callback) ->
    throw new Error("new ListSelection(): You must provide a view.") unless @_view
    @_unlisten = DatabaseStore.listen(@_applyChangeRecord, @)
    @_caches = {}
    @_items = []
    @trigger = =>
      @_caches = {}
      callback()

  cleanup: ->
    @_unlisten()

  count: ->
    @_items.length

  ids: ->
    # ListTabular asks for ids /a lot/. Cache this value and clear it on trigger.
    @_caches['ids'] ?= _.pluck(@_items, 'id')
    @_caches['ids']

  items: -> _.clone(@_items)

  top: ->
    @_items[@_items.length - 1]

  clear: ->
    @set([])

  set: (items) ->
    @_items = []
    for item in items
      throw new Error("set must be called with Models") unless item instanceof Model
      @_items.push(item)
    @trigger(@)

  toggle: (item) ->
    return unless item
    throw new Error("toggle must be called with a Model") unless item instanceof Model

    without = _.reject @_items, (t) -> t.clientId is item.clientId
    if without.length < @_items.length
      @_items = without
    else
      @_items.push(item)
    @trigger(@)

  add: (item) ->
    return unless item
    throw new Error("add must be called with a Model") unless item instanceof Model

    updated = _.reject @_items, (t) -> t.clientId is item.clientId
    updated.push(item)
    if updated.length isnt @_items.length
      @_items = updated
      @trigger(@)

  remove: (items) ->
    return unless items

    items = [items] unless items instanceof Array

    for item in items
      unless item instanceof Model
        throw new Error("remove: Must be passed a model or array of models")

    itemIds = _.pluck(items, 'id')

    without = _.reject @_items, (t) -> t.clientId in itemIds
    if without.length < @_items.length
      @_items = without
      @trigger(@)

  removeItemsNotMatching: (matchers) ->
    count = @_items.length
    @_items = _.filter @_items, (t) -> t.matches(matchers)
    if @_items.length isnt count
      @trigger(@)

  expandTo: (item) ->
    return unless item
    throw new Error("expandTo must be called with a Model") unless item instanceof Model

    if @_items.length is 0
      @_items.push(item)
    else
      # When expanding selection, you expand from the last selected item
      # to the item the user clicked on. If the item is already selected,
      # remove it from the selected array and reselect it so that the
      # items are in the _items array in the order they were selected.
      # (important for walking)
      relativeTo = @_items[@_items.length - 1]
      startIdx = @_view.indexOfId(relativeTo.clientId)
      endIdx = @_view.indexOfId(item.clientId)
      return if startIdx is -1 or endIdx is -1
      for idx in [startIdx..endIdx]
        item = @_view.get(idx)
        @_items = _.reject @_items, (t) -> t.clientId is item.clientId
        @_items.push(item)
    @trigger()

  walk: ({current, next}) ->
    # When the user holds shift and uses the arrow keys to modify their selection,
    # we call that "walking". When walking you're usually selecting items. However,
    # if you're walking "back" through your selection in the same order you selected
    # them, you're undoing selections you've made. The order of the _items array
    # is actually important - you can only deselect FROM the head back down the
    # selection history.

    ids = @ids()
    noSelection = @_items.length is 0
    neitherSelected = (not current or ids.indexOf(current.clientId) is -1) and (not next or ids.indexOf(next.clientId) is -1)

    if noSelection or neitherSelected
      @_items.push(current) if current
      @_items.push(next) if next
    else
      selectionPostPopHeadId = null
      if @_items.length > 1
        selectionPostPopHeadId = @_items[@_items.length - 2].clientId

      if next.clientId is selectionPostPopHeadId
        @_items.pop()
      else
        # Important: As you walk over this item, remove it and re-push it on the selected
        # array even if it's already there. That way, the items in _items are always
        # in the order you walked over them, and you can walk back to deselect them.
        @_items = _.reject @_items, (t) -> t.clientId is next.clientId
        @_items.push(next)

    @trigger()

  _applyChangeRecord: (change) ->
    return if @_items.length is 0
    return if change.objectClass isnt @_items[0].constructor.name

    if change.type is 'unpersist'
      @remove(change.objects)
    else if change.type is 'persist'
      touched = 0
      for newer in change.objects
        for existing, idx in @_items
          if existing.clientId is newer.clientId
            @_items[idx] = newer
            touched += 1
            break
      if touched > 0
        @trigger(@)
