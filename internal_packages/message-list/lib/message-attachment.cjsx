path = require 'path'
React = require 'react'
{Actions} = require 'inbox-exports'

# Passed in as props from MessageItem and FileDownloadStore
# This is empty if the attachment isn't downloading.
# @props.download is a FileDownloadStore.Download object
# @props.file is a File object

module.exports =
MessageAttachment = React.createClass
  displayName: 'MessageAttachment'

  propTypes:
    file: React.PropTypes.object.isRequired,
    download: React.PropTypes.object

  getInitialState: ->
    progressPercent: 0

  render: ->
    <div className={"attachment-file-wrap " + (@props.download?.state() ? "")}>
      <span className="attachment-download-bar-wrap">
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
    width: @props.download?.percent ? 0

  _onClickRemove: ->
    Actions.removeFile
      file: @props.file
      messageLocalId: @props.messageLocalId

  _onClickView: -> Actions.fetchAndOpenFile(@props.file) if @_canClickToView()

  _onClickDownload: -> Actions.fetchAndSaveFile(@props.file)

  _onClickAbort: -> Actions.abortDownload(@props.file, @props.download)

  _canClickToView: -> not @props.removable and not @_isDownloading()

  _isDownloading: -> @props.download?.state() is "downloading"
