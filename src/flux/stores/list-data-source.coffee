_ = require 'underscore'
EventEmitter = require('events').EventEmitter
ListSelection = require './list-selection'

module.exports =
class ListDataSource

  constructor: ->
    @_emitter = new EventEmitter()
    @selection = new ListSelection(@, @trigger)
    @

  # Accessing Data

  trigger: (arg) =>
    @_emitter.emit('trigger', arg)

  listen: (callback, bindContext) ->
    eventHandler = ->
      callback.apply(bindContext, arguments)
    @_emitter.addListener('trigger', eventHandler)
    return => @_emitter.removeListener('trigger', eventHandler)

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
