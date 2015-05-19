_ = require 'underscore'

module.exports =
class UndoManager
  constructor: ->
    @_position = -1
    @_history = []
    @_MAX_HISTORY_SIZE = 100

  current: ->
    return @_history[@_position]

  undo: ->
    if @_position > 0
      @_position -= 1
      return @_history[@_position]
    else return null

  redo: ->
    if @_position < (@_history.length - 1)
      @_position += 1
      return @_history[@_position]
    else return null

  immediatelySaveToHistory: (historyItem) =>
    if not _.isEqual((_.last(@_history) ? {}), historyItem)
      @_position += 1
      @_history.length = @_position
      @_history.push(historyItem)
      while @_history.length > @_MAX_HISTORY_SIZE
        @_history.shift()
        @_position -= 1

  saveToHistory: _.debounce(UndoManager::immediatelySaveToHistory, 300)
