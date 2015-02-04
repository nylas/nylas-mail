path = require 'path'
React = require 'react'
{Actions} = require 'inbox-exports'

# Passed in as props from MessageItem and FileDownloadStore
# Generated in tasks/download-file.coffee
# This is empty if the attachment isn't downloading.
# @props.downloadData:
#   state - One of "pending "started" "progress" "completed" "aborted" "failed"
#   fileId - The id of the file
#   shellAction - Action used to open the file after downloading
#   downloadPath - The full path of the download location
#   total - From request-progress: total number of bytes
#   percent - From request-progress
#   received - From request-progress: currently received bytes
#
# @props.file is a File object

module.exports =
MessageAttachment = React.createClass
  displayName: 'MessageAttachment'

  getInitialState: ->
    progressPercent: 0

  render: ->
    <div className={"attachment-file-wrap " + (@props.downloadData?.state ? "")}>

      <span className="attachment-download-bar-wrap" style={@_showDownload()}>
        <span className="attachment-bar-bg"></span>
        <span className="attachment-download-progress" style={@_downloadProgressStyle()}></span>
      </span>

      <span className="attachment-file-and-name" onClick={@_onClickView}>
        <span className="attachment-file-icon"><i className="fa fa-file-o"></i>&nbsp;</span>
        <span className="attachment-file-name">{@props.file.filename}</span>
      </span>

      <span className="attachment-file-actions">
        {@_fileActions()}
      </span>

    </div>

  _fileActions: ->
    if @props.removable
      <button className="btn btn-icon attachment-icon" onClick={@_onClickRemove}>
        <i className="fa fa-remove"></i>
      </button>
    else if @_isDownloading()
      <button className="btn btn-icon attachment-icon" onClick={@_onClickAbort}>
        <i className="fa fa-remove"></i>
      </button>
    else
      <button className="btn btn-icon attachment-icon" onClick={@_onClickDownload}>
        <i className="fa fa-download"></i>
      </button>

  _downloadProgressStyle: ->
    width: @props.downloadData?.percent ? 0

  _onClickRemove: ->
    Actions.removeFile
      file: @props.file
      messageLocalId: @props.messageLocalId

  _onClickView: -> Actions.viewFile(@props.file) if @_canClickToView()

  _onClickDownload: -> Actions.saveFile @props.file

  _onClickAbort: -> Actions.abortDownload(@props.file, @props.downloadData)

  _canClickToView: -> not @props.removable and not @_isDownloading()

  _showDownload: ->
    if @_isDownloading() then {display: "block"} else {display: "none"}

  _isDownloading: ->
    @props.downloadData?.state in ["pending", "started", "progress"]
