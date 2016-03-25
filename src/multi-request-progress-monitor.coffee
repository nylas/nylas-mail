class MultiRequestProgressMonitor

  constructor: ->
    @_requests = {}
    @_expected = {}

  add: (filepath, filesize, request) =>
    @_requests[filepath] = request
    @_expected[filepath] = filesize ? fs.statSync(filepath)["size"] ? 0

  remove: (filepath) =>
    delete @_requests[filepath]
    delete @_expected[filepath]

  requests: =>
    _.values(@_requests)

  value: =>
    sent = 0
    expected = 1
    for filepath, request of @_requests
      sent += request.req?.connection?._bytesDispatched ? 0
      expected += @_expected[filepath]

    return sent / expected

module.exports = MultiRequestProgressMonitor
