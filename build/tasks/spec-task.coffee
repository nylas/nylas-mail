fs = require 'fs'
path = require 'path'
request = require 'request'
proc = require 'child_process'

executeTests = (test, grunt, done) ->
  testSucceeded = false
  testOutput = ""

  testProc = proc.spawn(test.cmd, test.args, {stdio: "inherit"})

  # testProc.stdout.on 'data', (data) ->
  #   str = data.toString()
  #   testOutput += str
  #   console.log(str)
  #   if str.indexOf(' 0 failures') isnt -1
  #     testSucceeded = true
  #
  # testProc.stderr.on 'data', (data) ->
  #   str = data.toString()
  #   testOutput += str
  #   grunt.log.error(str)

  testProc.on 'error', (err) ->
    grunt.log.error("Process error: #{err}")

  testProc.on 'close', (exitCode, signal) ->
    if testSucceeded and exitCode is 0
      done()
    else
      testOutput = testOutput.replace(/\x1b\[[^m]+m/g, '')
      url = "https://hooks.slack.com/services/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"
      request.post
        url: url
        json:
          username: "Edgehill Builds"
          text: "Aghhh somebody broke the build. ```#{testOutput}```"
      , (err, httpResponse, body) ->
        done(false)

module.exports = (grunt) ->

  grunt.registerTask 'run-spectron-specs', 'Run spectron specs', ->
    rootDir = path.resolve('.')
    appPath = path.resolve('./electron/Electron.app/Contents/MacOS/Electron')

    done = @async()
    npmPath = path.resolve "./build/node_modules/.bin/npm"
    grunt.log.writeln 'App exists: ' + fs.existsSync(appPath)

    process.chdir('./spectron')
    grunt.log.writeln "Current dir: #{process.cwd()}"
    installProc = proc.exec "#{npmPath} install", (error) ->
      if error?
        process.chdir('..')
        grunt.log.error('Failed while running npm install in spectron folder')
        grunt.fail.warn(error)
        done(false)
      else
        appArgs = [
          'test'
          "APP_PATH=#{appPath}"
          "APP_ARGS=#{rootDir}"
        ]
        executeTests cmd: npmPath, args: appArgs, grunt, (succeeded) ->
          process.chdir('..')
          done(succeeded)


  grunt.registerTask 'run-edgehill-specs', 'Run the specs', ->
    done = @async()
    executeTests cmd: './N1.sh', args: ['--test'], grunt, done
