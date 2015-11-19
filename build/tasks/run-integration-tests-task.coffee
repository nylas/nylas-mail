path = require 'path'
childProcess = require 'child_process'

module.exports = (grunt) ->
  desc = "Boots Selenium via Spectron to run integration tests"
  grunt.registerTask 'run-integration-tests', desc, ->
    done = @async()

    rootPath = path.resolve('.')
    npmPath = path.join(rootPath, "build", "node_modules", ".bin", "npm")

    process.chdir('./spec_integration')
    testProc = childProcess.spawn(npmPath,
      ["test", "NYLAS_ROOT_PATH=#{rootPath}"],
      {stdio: "inherit"})

    testProc.on 'exit', (exitCode, signal) ->
      process.chdir('..')
      if exitCode is 0 then done()
      else done(false)
