path = require 'path'
React = require 'react'
AttachmentComponent = require './attachment-component'
{RetinaImg, Spinner, DraggableImg} = require 'nylas-component-kit'

class ImageAttachmentComponent extends AttachmentComponent
  @displayName: 'ImageAttachmentComponent'

  render: =>
    <div>
      <span className={"progress-bar-wrap state-#{@props.download?.state ? ""}"}>
        <span className="progress-background"></span>
        <span className="progress-foreground" style={@_downloadProgressStyle()}></span>
      </span>

      {@_renderFileActions()}

      <div className="file-preview" onDoubleClick={@_onClickView}>
        <div className="file-name-container">
          <div className="file-name">{@props.file.displayName()}</div>
        </div>
        {@_imgOrLoader()}
      </div>
    </div>

  _canAbortDownload: -> false

  _renderRemoveIcon: ->
    <RetinaImg name="image-cancel-button.png" mode={RetinaImg.Mode.ContentPreserve} />

  _renderDownloadButton: ->
    <RetinaImg name="image-download-button.png" mode={RetinaImg.Mode.ContentPreserve} />

  _imgOrLoader: ->
    if @props.download and @props.download.percent <= 5
      <div style={width: "100%", height: "100px"}>
        <Spinner visible={true} />
      </div>
    else if @props.download and @props.download.percent < 100
      <DraggableImg src={"#{@props.targetPath}?percent=#{@props.download.percent}"} />
    else
      <DraggableImg src={@props.targetPath} />

module.exports = ImageAttachmentComponent
