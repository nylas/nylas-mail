path = require 'path'
React = require 'react'
AttachmentComponent = require './attachment-component'
{Spinner, DraggableImg} = require 'nylas-component-kit'

class ImageAttachmentComponent extends AttachmentComponent
  @displayName: 'ImageAttachmentComponent'

  render: =>
    <div className={"attachment-inner-wrap " + @props.download?.state ? ""}>
      <span className="attachment-download-bar-wrap">
        <span className="attachment-bar-bg"></span>
        <span className="attachment-download-progress" style={@_downloadProgressStyle()}></span>
      </span>

      <span className="attachment-file-actions">
        {@_fileActions()}
      </span>

      <div className="attachment-preview" onClick={@_onClickView}>
        {@_imgOrLoader()}
      </div>

    </div>

  _canAbortDownload: -> false

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
