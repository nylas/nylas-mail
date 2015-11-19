childProcess = require 'child_process'

module.exports = (grunt) ->
  {notifyAPI} = require('./task-helpers')(grunt)

  desc = "Boots N1 in --test mode to run unit tests"
  grunt.registerTask 'run-unit-tests', desc, ->
    done = @async()

    testProc = childProcess.spawn("./N1.sh", ["--test"])

    testOutput = ""
    testProc.stdout.pipe(process.stdout)
    testProc.stderr.pipe(process.stderr)
    testProc.stdout.on 'data', (data) -> testOutput += data.toString()
    testProc.stderr.on 'data', (data) -> testOutput += data.toString()

    testProc.on 'error', (err) -> grunt.log.error("Process error: #{err}")

    testProc.on 'exit', (exitCode, signal) ->
      if exitCode is 0 then done()
      else
        testOutput = grunt.log.uncolor(testOutput)
        msg = "Aghhh somebody broke the build. ```#{testOutput}```"
        notifyAPI msg, -> done(false)
