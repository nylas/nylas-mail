path = require 'path'
React = require 'react'
{Actions,
 FileUploadStore} = require 'inbox-exports'

FileUpload = React.createClass
  render: ->
    <div className={"attachment-file-wrap " + @props.uploadData.state}>
      <span className="attachment-bar-bg"></span>
      <span className="attachment-upload-progress" style={@_uploadProgressStyle()}></span>
      <span className="attachment-file-and-name">
        <span className="attachment-file-icon"><i className="fa fa-file-o"></i>&nbsp;</span>
        <span className="attachment-file-name">{@_basename()}</span>
      </span>
      <span className="attachment-file-actions">
        <button className="btn btn-icon attachment-icon" onClick={@_onClickRemove}>
          <i className="fa fa-remove"></i>
        </button>
      </span>
    </div>

  _uploadProgressStyle: ->
    if @props.uploadData.fileSize <= 0
      percent = 0
    else
      percent = (@props.uploadData.bytesUploaded / @props.uploadData.fileSize) * 100
    width: "#{percent}%"

  _onClickRemove: ->
    Actions.abortUpload @props.uploadData

  _basename: ->
    path.basename(@props.uploadData.filePath)

module.exports =
FileUploads = React.createClass
  getInitialState: ->
    uploads: FileUploadStore.uploadsForMessage(@props.localId) ? []

  componentDidMount: ->
    @storeUnlisten = FileUploadStore.listen(@_onFileUploadStoreChange)

  componentWillUnmount: ->
    @storeUnlisten() if @storeUnlisten

  render: ->
    <span className="file-uploads">
      {@_fileUploads()}
    </span>

  _fileUploads: ->
    @state.uploads.map (uploadData) =>
      <FileUpload key={@_key(uploadData)} uploadData={uploadData} />

  _key: (uploadData) ->
    "#{uploadData.messageLocalId} #{uploadData.filePath}"

  # fileUploads:
  #   "some_local_msg_id /some/full/path/name":
  #     messageLocalId - The localId of the message (draft) we're uploading to
  #     filePath - The full absolute local system file path
  #     fileSize - The size in bytes
  #     fileName - The basename of the file
  #     bytesUploaded - Current number of bytes uploaded
  #     state - one of "started" "progress" "completed" "aborted" "failed"
  _onFileUploadStoreChange: ->
    @setState uploads: FileUploadStore.uploadsForMessage(@props.localId)
