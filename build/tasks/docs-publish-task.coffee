path = require 'path'
Handlebars = require 'handlebars'
marked = require 'meta-marked'
fs = require 'fs-plus'
_ = require 'underscore'

module.exports = (grunt) ->
  {cp, mkdir, rm} = require('./task-helpers')(grunt)

  grunt.registerTask 'publish-docs', 'Publish the API docs to gh-pages', ->
    done = @async()

    docsOutputDir = grunt.config.get('docsOutputDir')
    docsRepoDir = process.env.DOCS_REPO_DIR
    if not docsRepoDir
      console.log("DOCS_REPO_DIR is not set.")
      return done()

    exec = (require 'child_process').exec
    execAll = (arr, callback) ->
      console.log(arr[0])
      exec arr[0], {cwd: docsRepoDir}, (err, stdout, stderr) ->
        return callback(err) if callback and err
        arr.splice(0, 1)
        if arr.length > 0
          execAll(arr, callback)
        else
          callback(null)

    execAll [
      "git fetch"
      "git reset --hard origin/gh-pages"
      "git clean -Xdf"
    ], (err) ->
      return done(err) if err
      cp(docsOutputDir, docsRepoDir)
      execAll [
        "git commit -am 'Jenkins updating docs'"
        "git push --force origin/gh-pages"
      ], (err) ->
        return done(err)
