_ = require 'underscore'
fs = require 'fs-plus'
path = require 'path'
request = require 'request'

module.exports = (grunt) ->
  cp: (source, destination, {filter}={}) ->
    unless grunt.file.exists(source)
      grunt.fatal("Cannot copy non-existent #{source.cyan} to #{destination.cyan}")

    copyFile = (sourcePath, destinationPath) ->
      return if filter?(sourcePath) or filter?.test?(sourcePath)

      stats = fs.lstatSync(sourcePath)
      if stats.isSymbolicLink()
        grunt.file.mkdir(path.dirname(destinationPath))
        fs.symlinkSync(fs.readlinkSync(sourcePath), destinationPath)
      else if stats.isFile()
        grunt.file.copy(sourcePath, destinationPath)

      if grunt.file.exists(destinationPath)
        fs.chmodSync(destinationPath, fs.statSync(sourcePath).mode)

    if grunt.file.isFile(source)
      copyFile(source, destination)
    else
      try
        onFile = (sourcePath) ->
          destinationPath = path.join(destination, path.relative(source, sourcePath))
          copyFile(sourcePath, destinationPath)
        onDirectory = (sourcePath) ->
          if fs.isSymbolicLinkSync(sourcePath)
            destinationPath = path.join(destination, path.relative(source, sourcePath))
            copyFile(sourcePath, destinationPath)
            false
          else
            true
        fs.traverseTreeSync source, onFile, onDirectory
      catch error
        grunt.fatal(error)

    grunt.verbose.writeln("Copied #{source.cyan} to #{destination.cyan}.")

  mkdir: (args...) ->
    grunt.file.mkdir(args...)

  rm: (args...) ->
    grunt.file.delete(args..., force: true) if grunt.file.exists(args...)

  spawn: (options, callback) ->
    childProcess = require 'child_process'
    stdout = []
    stderr = []
    error = null
    proc = childProcess.spawn(options.cmd, options.args, options.opts)
    proc.stdout.on 'data', (data) -> stdout.push(data.toString())
    proc.stderr.on 'data', (data) -> stderr.push(data.toString())
    proc.on 'error', (processError) -> error ?= processError
    proc.on 'close', (exitCode, signal) ->
      error ?= new Error(signal) if exitCode != 0
      results = {stderr: stderr.join(''), stdout: stdout.join(''), code: exitCode}
      grunt.log.error results.stderr if exitCode != 0
      callback(error, results, exitCode)

  spawnP: (cmd, args=[], opts={}) -> new Promise (resolve, reject) ->
    childProcess = require 'child_process'
    opts.stdio ?= 'inherit'
    proc = childProcess.spawn(cmd, args, opts)
    proc.on 'error', grunt.fail.fatal
    proc.on 'close', (exitCode, signal) ->
      if exitCode is 0 then resolve() else reject(exitCode)

  isNylasPackage: (packagePath) ->
    try
      {engines} = grunt.file.readJSON(path.join(packagePath, 'package.json'))
      engines?.nylas?
    catch error
      false

  notifyAPI: (msg, callback) ->
    if (process.env.NYLAS_INTERNAL_HOOK_URL ? "").length > 0
      request.post
        url: process.env.NYLAS_INTERNAL_HOOK_URL
        json:
          username: "Edgehill Builds"
          text: msg
      , callback
    else callback()

  shouldPublishBuild: ->
    return false unless process.env.PUBLISH_BUILD
    if process.env.APPVEYOR
      if process.env.APPVEYOR_PULL_REQUEST_NUMBER
        grunt.log.writeln("Skipping because this is a pull request")
        return false

      branch = process.env.APPVEYOR_REPO_BRANCH
      if branch is "master" or branch is "ci-test" or branch is "stable"
        return true
      else
        grunt.log.writeln("Skipping. We don't operate on branch '#{branch}''")
        return false

    else if process.env.TRAVIS
      if process.env.TRAVIS_PULL_REQUEST isnt "false"
        grunt.log.writeln("Skipping because this is a pull request")
        return false

      branch = process.env.TRAVIS_BRANCH
      if branch is "master" or branch is "ci-test" or branch is "stable"
        return true
      else
        grunt.log.writeln("Skipping. We don't operate on branch '#{branch}''")
        return false
    return true

  fillTemplate: (templatePath, outputPath, data) ->
    content = _.template(String(fs.readFileSync(templatePath)))(data)
    grunt.file.write(outputPath, content)

