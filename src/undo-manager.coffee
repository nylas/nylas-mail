_ = require 'underscore'

module.exports =
class UndoManager
  constructor: ->
    @_historyIndex = -1
    @_markerIndex = -1
    @_history = []
    @_markers = []
    @_MAX_HISTORY_SIZE = 1000

  current: ->
    return @_history[@_historyIndex]

  undo: ->
    @__saveHistoryMarker()
    if @_historyIndex > 0
      @_markerIndex -= 1
      @_historyIndex = @_markers[@_markerIndex]
      return @_history[@_historyIndex]
    else return null

  redo: ->
    @__saveHistoryMarker()
    if @_historyIndex < (@_history.length - 1)
      @_markerIndex += 1
      @_historyIndex = @_markers[@_markerIndex]
      return @_history[@_historyIndex]
    else return null

  saveToHistory: (historyItem) =>
    if not _.isEqual((_.last(@_history) ? {}), historyItem)
      @_historyIndex += 1
      @_history.length = @_historyIndex
      @_history.push(historyItem)
      @_saveHistoryMarker()
      while @_history.length > @_MAX_HISTORY_SIZE
        @_history.shift()
        @_historyIndex -= 1

  __saveHistoryMarker: =>
    if @_markers[@_markerIndex] isnt @_historyIndex
      @_markerIndex += 1
      @_markers.length = @_markerIndex
      @_markers.push(@_historyIndex)
      while @_markers.length > @_MAX_HISTORY_SIZE
        @_markers.shift()
        @_markerIndex -= 1

  _saveHistoryMarker: _.debounce(UndoManager::__saveHistoryMarker, 300)
