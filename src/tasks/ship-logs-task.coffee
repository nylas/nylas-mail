fs = require 'fs'
path = require 'path'
request = require 'request'

module.exports = (dir, regexPattern) ->
  callback = @async()

  console.log("Running log ship: #{dir}, #{regexPattern}")

  fs.readdir dir, (err, files) ->
    console.log("readdir error: #{err}") if err
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
      console.log("No logs found to upload.")
      callback()
      console.log("Callback.")
      return

    console.log("Uploading #{logs} to S3")

    # The AWS Module does some really interesting stuff - it loads it's configuration
    # from JSON files. Unfortunately, when the app is built into an ASAR bundle, child
    # processes forked from the main process can't seem to access files inside the archive,
    # so AWS can't find it's JSON config. (5/20)
    if __dirname.indexOf('app.asar') != -1
      AWSModulePath = path.join(__dirname, '..','..','..', 'app.asar.unpacked', 'node_modules', 'aws-sdk')
    else
      AWSModulePath = 'aws-sdk'

    console.log("Load AWS module from #{AWSModulePath}")

    # Note: These credentials are only good for uploading to this
    # specific bucket and can't be used for anything else.
    AWS = require(AWSModulePath)
    AWS.config.update
      accessKeyId: 'AKIAIEGVDSVLK3Z7UVFA',
      secretAccessKey: '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'

    bucket = new AWS.S3({params: {Bucket: 'edgehill-client-logs'}})
    uploadTime = Date.now()

    logs.forEach (log) ->
      stream = fs.createReadStream(log, {flags: 'r'})
      key = "#{uploadTime}-#{path.basename(log)}"
      params = {Key: key, Body: stream}
      remaining += 1
      bucket.upload params, (err, data) ->
        if err
          console.log("Error uploading #{key}: #{err.toString()}")
        else
          console.log("Successfully uploaded #{key}")
        fs.truncate(log)
        finished()
