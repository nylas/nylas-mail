path = require 'path'
React = require 'react'
{RetinaImg} = require 'nylas-component-kit'
{Utils,
 Actions,
 FileUploadStore} = require 'nylas-exports'

class FileUpload extends React.Component
  @displayName: 'FileUpload'

  render: =>
    <div className={"file-upload attachment-file-wrap " + @props.uploadData.state}>
      <span className="attachment-bar-bg"></span>
      <span className="attachment-upload-progress" style={@_uploadProgressStyle()}></span>

      <span className="attachment-file-actions">
        <div className="attachment-icon" onClick={@_onClickRemove}>
          <RetinaImg className="remove-icon" name="remove-attachment.png"/>
        </div>
      </span>

      <span className="attachment-file-and-name">
        <span className="attachment-file-icon">
          <RetinaImg className="file-icon"
                     fallback="file-fallback.png"
                     name="file-#{@_extension()}.png"/>
        </span>
        <span className="attachment-file-name"><span className="uploading">Uploading:</span>&nbsp;{@_basename()}</span>
      </span>

    </div>

  _uploadProgressStyle: =>
    if @props.uploadData.fileSize <= 0
      percent = 0
    else
      percent = (@props.uploadData.bytesUploaded / @props.uploadData.fileSize) * 100
    width: "#{percent}%"

  _onClickRemove: =>
    Actions.abortUpload @props.uploadData

  _basename: =>
    path.basename(@props.uploadData.filePath)

  _extension: -> path.extname(@_basename()).split('.').pop()

module.exports = FileUpload
