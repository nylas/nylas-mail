_ = require 'underscore-plus'
fs = require 'fs'
path = require 'path'
progress = require('request-progress')

Task = require './task'
File = require '../models/file'
Actions = require '../actions'
NamespaceStore = require '../stores/namespace-store'

module.exports =
class DownloadFileTask extends Task
  constructor: ({@fileId, @downloadPath, @shellAction}) -> @

  performLocal: ->
    new Promise (resolve, reject) =>
      return reject(new Error("Must pass a fileID to download")) unless @fileId?
      return reject(new Error("Must have a path to download to")) unless @downloadPath?
      Actions.downloadStateChanged @_downloadData("pending")
      resolve()

  rollbackLocal: ->
    Actions.downloadStateChanged @_downloadData("failed")

  performRemote: ->
    new Promise (resolve, reject) =>
      Actions.downloadStateChanged @_downloadData("started")

      @request = atom.inbox.makeRequest(
        path: "/n/#{@_namespaceId()}/files/#{@fileId}/download"
        success: (data) =>
          Actions.downloadStateChanged @_downloadData("completed")
          Actions.fileDownloaded(@_downloadData("completed"))
          resolve()
        error: reject
      )

      progress(@request, {throtte: 250})
      .on("progress", (progressData) =>
        Actions.downloadStateChanged @_downloadData("progress", progressData)
      ).pipe(fs.createWriteStream(path.join(@downloadPath)))

  abort: ->
    @request?.abort()
    Actions.downloadStateChanged @_downloadData("aborted")

  # returns:
  #   state - One of "pending "started" "progress" "completed" "aborted" "failed"
  #   fileId - The id of the file
  #   shellAction - Action used to open the file after downloading
  #   downloadPath - The full path of the download location
  #   total - From request-progress: total number of bytes
  #   percent - From request-progress
  #   received - From request-progress: currently received bytes
  _downloadData: (state, progressData={}) ->
    _.extend progressData, {state: state},
      fileId: @fileId
      shellAction: @shellAction
      downloadPath: @downloadPath

  _namespaceId: -> NamespaceStore.current()?.id

