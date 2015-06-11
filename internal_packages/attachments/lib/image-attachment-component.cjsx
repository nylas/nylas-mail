path = require 'path'
React = require 'react'
AttachmentComponent = require './attachment-component'

class ImageAttachmentComponent extends AttachmentComponent
  @displayName: 'ImageAttachmentComponent'

  render: =>
    <div className={"attachment-inner-wrap " + @props.download?.state() ? ""}>
      <span className="attachment-download-bar-wrap">
        <span className="attachment-bar-bg"></span>
        <span className="attachment-download-progress" style={@_downloadProgressStyle()}></span>
      </span>

      <span className="attachment-file-actions">
        {@_fileActions()}
      </span>

      <div className="attachment-preview" onClick={@_onClickView}>
        <img src={@props.targetPath} />
      </div>

    </div>

module.exports = ImageAttachmentComponent
