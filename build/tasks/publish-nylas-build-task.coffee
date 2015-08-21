_ = require 'underscore'
s3 = require 's3'
fs = require 'fs'
path = require 'path'
request = require 'request'
Promise = require 'bluebird'

module.exports = (grunt) ->
  {cp, spawn, rm} = require('./task-helpers')(grunt)

  getVersion = ->
    {version} = require(path.join(grunt.config.get('atom.appDir'), 'package.json'))
    return version

  appName = -> grunt.config.get('atom.appName')
  dmgName = -> "#{appName().split('.')[0]}.dmg"
  zipName = -> "#{appName().split('.')[0]}.zip"

  defaultPublishPath = -> path.join(process.env.HOME, "Downloads")

  publishPath = ->
    process.env.PUBLISH_PATH ? defaultPublishPath()

  runEmailIntegrationTest = (s3Client) ->
    buildDir = grunt.config.get('atom.buildDir')
    buildVersion = getVersion()
    new Promise (resolve, reject) ->
      appToRun = path.join(buildDir, appName())
      scriptToRun = "./build/run-build-and-send-screenshot.scpt"
      spawn
        cmd: "osascript"
        args: [scriptToRun, appToRun, buildVersion]
      , (error) ->
        if error
          reject(error)
          return

  postToSlack = (msg) ->
    new Promise (resolve, reject) ->
      url = "https://hooks.slack.com/services/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"
      request.post
        url: url
        json:
          username: "Edgehill Builds"
          text: msg
      , (err, httpResponse, body) ->
        if err then reject(err)
        else resolve()

  # Returns a properly bound s3obj
  prepareS3 = ->
    awsKey = process.env.AWS_ACCESS_KEY_ID ? ""
    awsSecret = process.env.AWS_SECRET_ACCESS_KEY ? ""

    if awsKey.length is 0
      grunt.log.error "Please set the AWS_ACCESS_KEY_ID environment variable"
      return false
    if awsSecret.length is 0
      grunt.log.error "Please set the AWS_SECRET_ACCESS_KEY environment variable"
      return false

    s3Client = s3.createClient
      s3Options:
        accessKeyId: process.env.AWS_ACCESS_KEY_ID
        scretAccessKey: process.env.AWS_SECRET_ACCESS_KEY

    return s3Client

  uploadFile = (s3Client, localSource, destName) ->
    grunt.log.writeln ">> Uploading #{localSource} to S3…"

    write = grunt.log.writeln
    lastPc = 0

    new Promise (resolve, reject) ->
      uploader = s3Client.uploadFile
        localFile: localSource
        s3Params:
          Key: destName
          ACL: "public-read"
          Bucket: "edgehill"

      uploader.on "error", (err) ->
        reject(err)
      uploader.on "progress", ->
        pc = Math.round(uploader.progressAmount / uploader.progressTotal * 100.0)
        if pc isnt lastPc
          lastPc = pc
          write(">> Uploading #{destName} #{pc}%")
      uploader.on "end", (data) ->
        resolve(data)

  uploadDMGToS3 = (s3Client) ->
    destName = "#{process.platform}/Edgehill_#{getVersion()}.dmg"
    dmgPath = path.join(grunt.config.get('atom.buildDir'), dmgName())
    new Promise (resolve, reject) ->
      uploadFile(s3Client, dmgPath, destName)
      .then (data) ->
        grunt.log.ok "Uploaded DMG to #{data.Location}"
        msg = "New Mac Edgehill build! <#{data.Location}|#{destName}>"
        postToSlack(msg).then ->
          resolve(data)
        .catch(reject)
      .catch(reject)

  uploadZipToS3 = (s3Client) ->
    destName = "#{process.platform}/Edgehill_#{getVersion()}.zip"
    buildDir = grunt.config.get('atom.buildDir')

    grunt.log.writeln ">> Creating zip file…"
    new Promise (resolve, reject) ->
      appToZip = path.join(buildDir, appName())
      zipPath = path.join(buildDir, zipName())

      rm zipPath

      orig = process.cwd()
      process.chdir(buildDir)

      spawn
        cmd: "zip"
        args: ["-9", "-y", "-r", zipName(), appName()]
      , (error) ->
        if error
          process.chdir(orig)
          reject(error)
          return

        grunt.log.writeln ">> Created #{zipPath}"
        grunt.log.writeln ">> Uploading…"
        uploadFile(s3Client, zipPath, destName)
        .then (data) ->
          grunt.log.ok "Uploaded zip to #{data.Location}"
          process.chdir(orig)
          resolve(data)
        .catch (err) ->
          process.chdir(orig)
          reject(err)

  grunt.registerTask "publish-nylas-build", "Publish Nylas build", ->
    done = @async()
    dmgPath = path.join(grunt.config.get('atom.buildDir'), dmgName())

    if not fs.existsSync dmgPath
      grunt.log.error "DMG does not exist at #{dmgPath}. Run script/grunt build first."
    cp dmgPath, path.join(publishPath(), dmgName())

    grunt.log.ok "Copied DMG to #{publishPath()}"
    if publishPath() is defaultPublishPath()
      grunt.log.ok "Set the PUBLISH_PATH environment variable to change where Edgehill copies the built file to."

    s3Client = prepareS3()
    if s3Client
      runEmailIntegrationTest().then ->
        Promise.all([uploadDMGToS3(s3Client), uploadZipToS3(s3Client)])
        .then ->
          done()
        .catch (err) ->
          grunt.log.error(err)
          return false
    else
      return false
