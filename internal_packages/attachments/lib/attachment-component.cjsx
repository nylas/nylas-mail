_ = require 'underscore'
path = require 'path'
React = require 'react'
{RetinaImg} = require 'nylas-component-kit'
{Actions, Utils} = require 'nylas-exports'

# Passed in as props from MessageItem and FileDownloadStore
# This is empty if the attachment isn't downloading.
# @props.download is a FileDownloadStore.Download object
# @props.file is a File object

class AttachmentComponent extends React.Component
  @displayName: 'AttachmentComponent'

  @propTypes:
    file: React.PropTypes.object.isRequired,
    download: React.PropTypes.object
    removable: React.PropTypes.bool
    targetPath: React.PropTypes.string
    messageLocalId: React.PropTypes.string

  constructor: (@props) ->
    @state = progressPercent: 0

  render: =>
    <div className={"attachment-inner-wrap #{@props.download?.state ? ""}"}>
      <span className="attachment-download-bar-wrap">
        <span className="attachment-bar-bg"></span>
        <span className="attachment-download-progress" style={@_downloadProgressStyle()}></span>
      </span>

      <span className="attachment-file-actions">
        {@_fileActions()}
      </span>

      <span className="attachment-file-and-name" onClick={@_onClickView}>
        <span className="attachment-file-icon">
          <RetinaImg className="file-icon"
                     fallback="file-fallback.png"
                     name="file-#{@_extension()}.png"/>
        </span>
        <span className="attachment-file-name">{@props.file.filename}</span>
      </span>

    </div>

  _fileActions: =>
    if @props.removable
      <div className="attachment-icon" onClick={@_onClickRemove}>
        <RetinaImg className="remove-icon" name="remove-attachment.png"/>
      </div>
    else if @_isDownloading() and @_canAbortDownload()
      <div className="attachment-icon" onClick={@_onClickAbort}>
        <RetinaImg className="remove-icon" name="remove-attachment.png"/>
      </div>
    else
      <div className="attachment-icon" onClick={@_onClickDownload}>
        <i className="fa fa-download" style={position: "relative", top: "2px"}></i>
      </div>

  _downloadProgressStyle: =>
    width: "#{@props.download?.percent ? 0}%"

  _onClickRemove: =>
    Actions.removeFile
      file: @props.file
      messageLocalId: @props.messageLocalId

  _canAbortDownload: -> true

  _onClickView: => Actions.fetchAndOpenFile(@props.file) if @_canClickToView()

  _onClickDownload: => Actions.fetchAndSaveFile(@props.file)

  _onClickAbort: => Actions.abortDownload(@props.file, @props.download)

  _canClickToView: => not @props.removable and not @_isDownloading()

  _isDownloading: => @props.download?.state is "downloading"

  _extension: -> @props.file.filename.split('.').pop()


module.exports = AttachmentComponent
