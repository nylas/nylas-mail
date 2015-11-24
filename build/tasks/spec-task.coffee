fs = require 'fs'
path = require 'path'
request = require 'request'
childProcess = require 'child_process'

executeTests = ({cmd, args}, grunt, done) ->
  testProc = childProcess.spawn(cmd, args)

  testOutput = ""
  testProc.stdout.pipe(process.stdout)
  testProc.stderr.pipe(process.stderr)
  testProc.stdout.on 'data', (data) -> testOutput += data.toString()
  testProc.stderr.on 'data', (data) -> testOutput += data.toString()

  testProc.on 'error', (err) -> grunt.log.error("Process error: #{err}")

  testProc.on 'exit', (exitCode, signal) ->
    if exitCode is 0 then done()
    else notifyOfTestError(testOutput, grunt).then -> done(false)

notifyOfTestError = (testOutput, grunt) -> new Promise (resolve, reject) ->
  if (process.env("TEST_ERROR_HOOK_URL") ? "").length > 0
    testOutput = grunt.log.uncolor(testOutput)
    request.post
      url: process.env("TEST_ERROR_HOOK_URL")
      json:
        username: "Edgehill Builds"
        text: "Aghhh somebody broke the build. ```#{testOutput}```"
    , resolve
  else resolve()

module.exports = (grunt) ->

  grunt.registerTask 'run-spectron-specs', 'Run spectron specs', ->
    shellAppDir = grunt.config.get('nylasGruntConfig.shellAppDir')

    if process.platform is 'darwine'
      executablePath = path.join(shellAppDir, 'Contents', 'MacOS', 'Nylas')
    else
      executablePath = path.join(shellAppDir, 'nylas')

    done = @async()
    npmPath = path.resolve "./build/node_modules/.bin/npm"

    #if process.platform isnt 'darwin'
    #  grunt.log.error("run-spectron-specs only works on Mac OS X at the moment.")
    #  done(false)

    if not fs.existsSync(executablePath)
      grunt.log.error("run-spectron-specs requires the built version of the app at #{executablePath}")
      done(false)

    process.chdir('./spectron')
    grunt.log.writeln "Current dir: #{process.cwd()}"
    installProc = childProcess.exec "#{npmPath} install", (error) ->
      if error?
        process.chdir('..')
        grunt.log.error('Failed while running npm install in spectron folder')
        grunt.fail.warn(error)
        done(false)
      else
        appArgs = [
          'test'
          "APP_PATH=#{executablePath}"
          "APP_ARGS="
        ]
        executeTests cmd: npmPath, args: appArgs, grunt, (succeeded) ->
          process.chdir('..')
          done(succeeded)


  grunt.registerTask 'run-edgehill-specs', 'Run the specs', ->
    done = @async()
    executeTests cmd: './N1.sh', args: ['--test'], grunt, done
