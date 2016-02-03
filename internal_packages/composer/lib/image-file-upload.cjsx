path = require 'path'
React = require 'react'
FileUpload = require './file-upload'
{RetinaImg} = require 'nylas-component-kit'

class ImageFileUpload extends FileUpload
  @displayName: 'ImageFileUpload'

  @propTypes:
    uploadData: React.PropTypes.object

  render: =>
    <div className="file-wrap file-image-wrap file-upload">
      <div className="file-action-icon" onClick={@_onClickRemove}>
        <RetinaImg name="image-cancel-button.png" mode={RetinaImg.Mode.ContentPreserve}/>
      </div>

      <div className="file-preview">
        <div className="file-name-container">
          <div className="file-name">{@props.upload.filename}</div>
        </div>

        <img src={@props.upload.targetPath} onDragStart={@_onDragStart}/>
      </div>
    </div>

  _onDragStart: (event) ->
    event.preventDefault()

module.exports = ImageFileUpload
