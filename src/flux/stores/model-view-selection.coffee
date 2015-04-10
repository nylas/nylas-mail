Model = require '../models/model'
_ = require 'underscore-plus'

module.exports =
class ModelViewSelection

  constructor: (@_view, @trigger) ->
    throw new Error("new ModelViewSelection(): You must provide a view.") unless @_view
    @_items = []

  count: ->
    @_items.length

  ids: ->
    _.pluck(@_items, 'id')

  items: ->
    @_items

  clear: ->
    @set([])

  set: (items) ->
    @_items = []
    for item in items
      throw new Error("selectItems must be called with Models") unless item instanceof Model
      @_items.push(item)
    @trigger(@)

  updateModelReferences: (items = []) ->
    for newer in items
      for existing, idx in @_items
        if existing.id is newer.id
          @_items[idx] = newer
          break

  toggle: (item) ->
    without = _.reject @_items, (t) -> t.id is item.id
    if without.length < @_items.length
      @_items = without
    else
      @_items.push(item)
    @trigger(@)

  remove: (item) ->
    without = _.reject @_items, (t) -> t.id is item.id
    if without.length < @_items.length
      @_items = without
      @trigger(@)

  expandTo: (item) ->
    if @_items.length is 0
      @_items.push(item)
    else
      # When expanding selection, you expand from the last selected item
      # to the item the user clicked on. If the item is already selected,
      # remove it from the selected array and reselect it so that the
      # items are in the _items array in the order they were selected.
      # (important for walking)
      relativeTo = @_items[@_items.length - 1]
      startIdx = @_view.indexOfId(relativeTo.id)
      endIdx = @_view.indexOfId(item.id)
      return if startIdx is -1 or endIdx is -1
      for idx in [startIdx..endIdx]
        item = @_view.get(idx)
        @_items = _.reject @_items, (t) -> t.id is item.id
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
    neitherSelected = (not current or ids.indexOf(current.id) is -1) and (not next or ids.indexOf(next.id) is -1)

    if noSelection or neitherSelected
      @_items.push(current) if current
      @_items.push(next) if next
    else
      selectionPostPopHeadId = null
      if @_items.length > 1
        selectionPostPopHeadId = @_items[@_items.length - 2].id

      if next.id is selectionPostPopHeadId
        @_items.pop()
      else
        # Important: As you walk over this item, remove it and re-push it on the selected
        # array even if it's already there. That way, the items in _items are always
        # in the order you walked over them, and you can walk back to deselect them.
        @_items = _.reject @_items, (t) -> t.id is next.id
        @_items.push(next)

    @trigger()
