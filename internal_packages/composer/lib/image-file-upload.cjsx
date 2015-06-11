path = require 'path'
React = require 'react'
FileUpload = require './file-upload'
{RetinaImg} = require 'nylas-component-kit'

class ImageFileUpload extends FileUpload
  @displayName: 'ImageFileUpload'

  @propTypes:
    uploadData: React.PropTypes.object

  render: =>
    <div className="image-file-upload #{@props.uploadData.state}">
      <span className="attachment-file-actions">
        <div className="attachment-icon" onClick={@_onClickRemove}>
          <RetinaImg className="remove-icon" name="remove-attachment.png"/>
        </div>
      </span>

      <div className="attachment-preview" >
        <img src={@props.uploadData.filePath} />
      </div>

      <span className="attachment-upload-progress" style={@_uploadProgressStyle()}></span>

    </div>

module.exports = ImageFileUpload
