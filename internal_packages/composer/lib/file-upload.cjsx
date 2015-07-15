path = require 'path'
React = require 'react'
{RetinaImg, Flexbox} = require 'nylas-component-kit'
{Utils,
 Actions,
 FileUploadStore} = require 'nylas-exports'

class FileUpload extends React.Component
  @displayName: 'FileUpload'

  render: =>
    <div className={"file-wrap file-upload"}>
      <div className="inner">
        <div className={"progress-bar-wrap state-#{@props.uploadData.state}"}>
          <span className="progress-background"></span>
          <span className="progress-foreground" style={@_uploadProgressStyle()}></span>
        </div>

        <Flexbox direction="row" style={alignItems: 'center'}>
          <RetinaImg className="file-icon"
                     fallback="file-fallback.png"
                     name="file-#{@_extension()}.png"/>
          <span className="file-name">
            <span className="uploading">Uploading:</span>&nbsp;{@_basename()}
          </span>
          <div className="file-action-icon" onClick={@_onClickRemove}>
            <RetinaImg name="remove-attachment.png"/>
          </div>
        </Flexbox>
      </div>
    </div>

  _uploadProgressStyle: =>
    if @props.uploadData.fileSize <= 0
      percent = 0
    else
      percent = Math.min(1, (@props.uploadData.bytesUploaded / @props.uploadData.fileSize)) * 100
    width: "#{percent}%"

  _onClickRemove: =>
    Actions.abortUpload @props.uploadData

  _basename: =>
    path.basename(@props.uploadData.filePath)

  _extension: -> path.extname(@_basename()).split('.').pop()

module.exports = FileUpload
