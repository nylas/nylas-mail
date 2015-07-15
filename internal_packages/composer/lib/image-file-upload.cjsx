path = require 'path'
React = require 'react'
FileUpload = require './file-upload'
{RetinaImg, DraggableImg} = require 'nylas-component-kit'

class ImageFileUpload extends FileUpload
  @displayName: 'ImageFileUpload'

  @propTypes:
    uploadData: React.PropTypes.object

  render: =>
    <div className="file-wrap file-image-wrap file-upload">
      <div className="file-action-icon" onClick={@_onClickRemove}>
        <RetinaImg name="image-cancel-button.png"/>
      </div>

      <div className="file-preview">
        <div className="file-name-container">
          <div className="file-name">{@props.uploadData.fileName}</div>
        </div>

        <DraggableImg src={@props.uploadData.filePath} />
      </div>

      <div className={"progress-bar-wrap state-#{@props.uploadData.state}"}>
        <span className="progress-foreground" style={@_uploadProgressStyle()}></span>
      </div>
    </div>

module.exports = ImageFileUpload
