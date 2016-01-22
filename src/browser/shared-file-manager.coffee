class SharedFileManager

  constructor: ->
    @_inflight = {}

  processWillWriteFile: (filePath) ->
    @_inflight[filePath] += 1

  processDidWriteFile: (filePath) ->
    @_inflight[filePath] -= 1

  processCanReadFile: (filePath) ->
    !@_inflight[filePath] or @_inflight[filePath] is 0

module.exports = SharedFileManager
