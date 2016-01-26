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
        <Flexbox direction="row" style={alignItems: 'center'}>
          <RetinaImg className="file-icon"
                     fallback="file-fallback.png"
                     mode={RetinaImg.Mode.ContentPreserve}
                     name="file-#{@_extension()}.png"/>
          <span className="file-name">
            <span className="uploading">{@props.upload.filename}</span>
          </span>
          <div className="file-action-icon" onClick={@_onClickRemove}>
            <RetinaImg name="remove-attachment.png" mode={RetinaImg.Mode.ContentDark} />
          </div>
        </Flexbox>
      </div>
    </div>

  _onClickRemove: =>
    Actions.removeFileFromUpload @props.upload.messageClientId, @props.upload.id

  _extension: =>
    path.extname(@props.upload.filename)[1..-1]

module.exports = FileUpload
