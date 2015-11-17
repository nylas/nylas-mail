describe '"nylas" protocol URL', ->
  it 'sends the file relative in the package as response', ->
    called = false
    request = new XMLHttpRequest()
    request.addEventListener('load', -> called = true)
    request.open('GET', 'nylas://async/package.json', true)
    request.send()

    waitsFor 'request to be done', -> called is true
