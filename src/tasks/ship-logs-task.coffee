fs = require 'fs'
path = require 'path'
request = require 'request'

detailedLogging = true
detailedLog = (msg) ->
  console.log(msg) if detailedLogging

module.exports = (dir, regexPattern) ->
  callback = @async()

  console.log("Running log ship: #{dir}, #{regexPattern}")

  fs.readdir dir, (err, files) ->
    log("readdir error: #{err}") if err
    logs = []
    logFilter = new RegExp(regexPattern)
    for file in files
      if logFilter.test(file)
        filepath = path.join(dir, file)
        stats = fs.statSync(filepath)
        logs.push(filepath) if stats["size"] > 0

    remaining = 0
    finished = ->
      remaining -= 1
      if remaining is 0
        callback()

    if logs.length is 0
      detailedLog("No logs found to upload.")
      callback()
      return

    logs.forEach (log) ->
      remaining += 1
      url = 'https://edgehill.nylas.com/ingest-log'
      formData =
        file:
          value: fs.createReadStream(log, {flags: 'r'})
          options:
            filename: 'log.txt',
            contentType: 'text/plain'

      request.post {url, formData}, (err, response, body) ->
        if err
          detailedLog("Error uploading #{log}: #{err.toString()}")
        else if response.statusCode isnt 200
          detailedLog("Error uploading #{log}: status code #{response.statusCode}")
        else
          detailedLog("Successfully uploaded #{log}")
        fs.truncate log, (err) =>
          console.log(err) if err
          fs.unlink log, (err) =>
            console.log(err) if err
        finished()
