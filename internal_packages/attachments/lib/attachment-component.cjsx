_ = require 'underscore'
path = require 'path'
fs = require 'fs'
React = require 'react'
{RetinaImg, Flexbox} = require 'nylas-component-kit'
{Actions, Utils, FileDownloadStore} = require 'nylas-exports'

class AttachmentComponent extends React.Component
  @displayName: 'AttachmentComponent'

  @propTypes:
    file: React.PropTypes.object.isRequired
    download: React.PropTypes.object
    removable: React.PropTypes.bool
    targetPath: React.PropTypes.string
    messageClientId: React.PropTypes.string

  constructor: (@props) ->
    @state = progressPercent: 0

  render: =>
    <div className="inner" onDoubleClick={@_onClickView} onDragStart={@_onDragStart} draggable="true">
      <span className={"progress-bar-wrap state-#{@props.download?.state ? ""}"}>
        <span className="progress-background"></span>
        <span className="progress-foreground" style={@_downloadProgressStyle()}></span>
      </span>

      <Flexbox direction="row" style={alignItems: 'center'}>
        <RetinaImg className="file-icon"
                   fallback="file-fallback.png"
                   mode={RetinaImg.Mode.ContentPreserve}
                   name="file-#{@props.file.displayExtension()}.png"/>
        <span className="file-name">{@props.file.displayName()}</span>
        {@_renderFileActions()}
      </Flexbox>
    </div>

  _renderFileActions: =>
    if @props.removable
      <div className="file-action-icon" onClick={@_onClickRemove}>
        {@_renderRemoveIcon()}
      </div>
    else if @_isDownloading() and @_canAbortDownload()
      <div className="file-action-icon" onClick={@_onClickAbort}>
        {@_renderRemoveIcon()}
      </div>
    else
      <div className="file-action-icon" onClick={@_onClickDownload}>
        {@_renderDownloadButton()}
      </div>

  _downloadProgressStyle: =>
    width: "#{@props.download?.percent ? 0}%"

  _canAbortDownload: -> true

  _canClickToView: => not @props.removable

  _isDownloading: => @props.download?.state is "downloading"

  _renderRemoveIcon: ->
    <RetinaImg name="remove-attachment.png" mode={RetinaImg.Mode.ContentPreserve} />

  _renderDownloadButton: ->
    <RetinaImg name="icon-attachment-download.png" mode={RetinaImg.Mode.ContentPreserve} />

  _onDragStart: (event) =>
    path = FileDownloadStore.pathForFile(@props.file)
    if fs.existsSync(path)
      DownloadURL = "#{@props.file.contentType}:#{@props.file.displayName()}:file://#{path}"
      event.dataTransfer.setData("DownloadURL", DownloadURL)
      event.dataTransfer.setData("text/nylas-file-url", DownloadURL)
    else
      event.preventDefault()
    return

  _onClickView: =>
    Actions.fetchAndOpenFile(@props.file) if @_canClickToView()

  _onClickRemove: (event) =>
    Actions.removeFile
      file: @props.file
      messageClientId: @props.messageClientId
    event.stopPropagation() # Prevent 'onClickView'

  _onClickDownload: (event) =>
    Actions.fetchAndSaveFile(@props.file)
    event.stopPropagation() # Prevent 'onClickView'

  _onClickAbort: (event) =>
    Actions.abortFetchFile(@props.file)
    event.stopPropagation() # Prevent 'onClickView'


module.exports = AttachmentComponent
