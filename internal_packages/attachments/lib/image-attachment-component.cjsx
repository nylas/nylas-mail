path = require 'path'
React = require 'react'
AttachmentComponent = require './attachment-component'
{RetinaImg, Spinner, DraggableImg} = require 'nylas-component-kit'

class ImageAttachmentComponent extends AttachmentComponent
  @displayName: 'ImageAttachmentComponent'

  render: =>
    <div className={"attachment-inner-wrap " + @props.download?.state ? ""}>
      <span className="attachment-download-bar-wrap">
        <span className="attachment-bar-bg"></span>
        <span className="attachment-download-progress" style={@_downloadProgressStyle()}></span>
      </span>

      <div className="attachment-file-actions">
        {@_fileActions()}
      </div>

      <div className="attachment-preview" onClick={@_onClickView}>
        <div className="attachment-name-bg"></div>
        <div className="attachment-name">{@props.file.filename}</div>
        {@_imgOrLoader()}
      </div>

    </div>

  _canAbortDownload: -> false

  _renderRemoveIcon: ->
    <RetinaImg className="image-remove-icon" name="image-cancel-button.png"/>

  _renderDownloadButton: ->
    <RetinaImg className="image-download-icon" name="image-download-button.png"/>

  _imgOrLoader: ->
    if @props.download
      if @props.download.percent <= 5
        <div style={width: "100%", height: "100px"}>
          <Spinner visible={true} />
        </div>
      else
        <DraggableImg src={"#{@props.targetPath}?percent=#{@props.download.percent}"} />
    else
      <DraggableImg src={@props.targetPath} />

module.exports = ImageAttachmentComponent
