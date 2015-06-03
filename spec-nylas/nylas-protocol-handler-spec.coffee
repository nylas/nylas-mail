{$} = require '../src/space-pen-extensions'

describe '"nylas" protocol URL', ->
  it 'sends the file relative in the package as response', ->
    called = false
    callback = -> called = true
    $.ajax
      url: 'nylas://async/package.json'
      success: callback
      # In old versions of jQuery, ajax calls to custom protocol would always
      # be treated as error eventhough the browser thinks it's a success
      # request.
      error: callback

    waitsFor 'request to be done', -> called is true
