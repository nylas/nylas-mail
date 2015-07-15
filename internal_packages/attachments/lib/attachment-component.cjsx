_ = require 'underscore'
path = require 'path'
React = require 'react'
{RetinaImg, Flexbox} = require 'nylas-component-kit'
{Actions, Utils, FileDownloadStore} = require 'nylas-exports'

# Passed in as props from MessageItem and FileDownloadStore
# This is empty if the attachment isn't downloading.
# @props.download is a FileDownloadStore.Download object
# @props.file is a File object
{DragDropMixin} = require 'react-dnd'

AttachmentDragContainer = React.createClass
  displayName: "AttachmentDragContainer"
  mixins: [DragDropMixin]
  statics:
    configureDragDrop: (registerType) =>
      registerType('attachment', {
        dragSource:
          beginDrag: (component) =>
            # Why is event defined in this scope? Magic. We need to use react-dnd
            # because otherwise it's global onDragStart listener will cancel the
            # drag. We don't actually intend to do a react-dnd drag/drop, but we
            # can use this hook to populate the event.dataTransfer
            DownloadURL = component.props.downloadUrl
            event.dataTransfer.setData("DownloadURL", DownloadURL)
            event.dataTransfer.setData("text/nylas-file-url", DownloadURL)

            # This is bogus we don't care about the rest of the react-dnd lifecycle.
            return {item: {DownloadURL}}
      })

  render: ->
    <div {...@dragSourceFor('attachment')} draggable="true">
      {@props.children}
    </div>

class AttachmentComponent extends React.Component
  @displayName: 'AttachmentComponent'

  @propTypes:
    file: React.PropTypes.object.isRequired
    download: React.PropTypes.object
    removable: React.PropTypes.bool
    targetPath: React.PropTypes.string
    messageLocalId: React.PropTypes.string

  constructor: (@props) ->
    @state = progressPercent: 0

  render: =>
    <AttachmentDragContainer downloadUrl={@_getDragDownloadURL()}>
      <div className="inner" onClick={@_onClickView}>
        <span className={"progress-bar-wrap state-#{@props.download?.state ? ""}"}>
          <span className="progress-background"></span>
          <span className="progress-foreground" style={@_downloadProgressStyle()}></span>
        </span>

        <Flexbox direction="row" style={alignItems: 'center'}>
          <RetinaImg className="file-icon"
                     fallback="file-fallback.png"
                     name="file-#{@_extension()}.png"/>
          <span className="file-name">{@props.file.displayName()}</span>
          {@_renderFileActions()}
        </Flexbox>
      </div>
    </AttachmentDragContainer>

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

  _canClickToView: => not @props.removable and not @_isDownloading()

  _isDownloading: => @props.download?.state is "downloading"

  _renderRemoveIcon: ->
    <RetinaImg name="remove-attachment.png"/>

  _renderDownloadButton: ->
    <RetinaImg name="icon-attachment-download.png"/>

  _getDragDownloadURL: (event) =>
    path = FileDownloadStore.pathForFile(@props.file)
    return "#{@props.file.contentType}:#{@props.file.displayName()}:file://#{path}"

  _onClickView: => Actions.fetchAndOpenFile(@props.file) if @_canClickToView()

  _onClickRemove: (event) =>
    Actions.removeFile
      file: @props.file
      messageLocalId: @props.messageLocalId
    event.stopPropagation() # Prevent 'onClickView'

  _onClickDownload: (event) =>
    Actions.fetchAndSaveFile(@props.file)
    event.stopPropagation() # Prevent 'onClickView'

  _onClickAbort: (event) =>
    Actions.abortDownload(@props.file, @props.download)
    event.stopPropagation() # Prevent 'onClickView'

  _extension: -> @props.file.filename.split('.').pop()


module.exports = AttachmentComponent
