path = require 'path'
React = require 'react'
FileUpload = require './file-upload'
{RetinaImg, DraggableImg} = require 'nylas-component-kit'

class ImageFileUpload extends FileUpload
  @displayName: 'ImageFileUpload'

  @propTypes:
    uploadData: React.PropTypes.object

  render: =>
    <div className="image-file-upload #{@props.uploadData.state}">
      <div className="attachment-file-actions">
        <div className="attachment-icon" onClick={@_onClickRemove}>
          <RetinaImg className="image-remove-icon" name="image-cancel-button.png"/>
        </div>
      </div>

      <div className="attachment-preview" >
        <div className="attachment-name-bg"></div>
        <div className="attachment-name">{@props.uploadData.fileName}</div>
        <DraggableImg src={@props.uploadData.filePath} />
      </div>

      <span className="attachment-upload-progress" style={@_uploadProgressStyle()}></span>

    </div>

module.exports = ImageFileUpload
