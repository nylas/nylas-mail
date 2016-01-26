_ = require 'underscore'
EventEmitter = require('events').EventEmitter
ListSelection = require './list-selection'

class ListDataSource
  constructor: ->
    @_emitter = new EventEmitter()
    @_cleanedup = false
    @selection = new ListSelection(@, @trigger)
    @

  # Accessing Data

  trigger: (arg) =>
    @_emitter.emit('trigger', arg)

  listen: (callback, bindContext) ->
    unless callback instanceof Function
      throw new Error("ListDataSource: You must pass a function to `listen`")
    if @_cleanedup is true
      throw new Error("ListDataSource: You cannot listen again after removing the last listener. This is an implementation detail.")

    eventHandler = ->
      callback.apply(bindContext, arguments)
    @_emitter.addListener('trigger', eventHandler)

    return =>
      @_emitter.removeListener('trigger', eventHandler)
      if @_emitter.listenerCount('trigger') is 0
        @_cleanedup = true
        @cleanup()

  loaded: ->
    throw new Error("ListDataSource base class does not implement loaded()")

  empty: ->
    throw new Error("ListDataSource base class does not implement empty()")

  get: (idx) ->
    throw new Error("ListDataSource base class does not implement get()")

  getById: (id) ->
    throw new Error("ListDataSource base class does not implement getById()")

  indexOfId: (id) ->
    throw new Error("ListDataSource base class does not implement indexOfId()")

  count: ->
    throw new Error("ListDataSource base class does not implement count()")

  itemsCurrentlyInViewMatching: (matchFn) ->
    throw new Error("ListDataSource base class does not implement itemsCurrentlyInViewMatching()")

  setRetainedRange: ({start, end}) ->
    throw new Error("ListDataSource base class does not implement setRetainedRange()")

  cleanup: ->
    @selection.cleanup()

class EmptyListDataSource extends ListDataSource
  loaded: -> true
  empty: -> true
  get: (idx) -> null
  getById: (id) -> null
  indexOfId: (id) -> -1
  count: -> 0
  itemsCurrentlyInViewMatching: (matchFn) -> []
  setRetainedRange: ({start, end}) ->

ListDataSource.Empty = EmptyListDataSource

module.exports = ListDataSource
