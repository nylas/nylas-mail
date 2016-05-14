import fs from 'fs'
import path from 'path'
import React, {Component, PropTypes} from 'react'
import {RetinaImg, Flexbox} from 'nylas-component-kit'
import {Actions, FileDownloadStore} from 'nylas-exports'


class AttachmentComponent extends Component {
  static displayName = 'AttachmentComponent';

  static propTypes = {
    file: PropTypes.object.isRequired,
    download: PropTypes.object,
    removable: PropTypes.bool,
    targetPath: PropTypes.string,
    messageClientId: PropTypes.string,
  };

  static containerRequired = false;

  constructor() {
    super()
    this.state = {progressPercent: 0}
  }

  _isDownloading() {
    const {download} = this.props
    const state = download ? download.state : null
    return state === 'downloading'
  }

  _canClickToView() {
    return !this.props.removable
  }

  _canAbortDownload() {
    return true
  }

  _downloadProgressStyle() {
    const {download} = this.props
    const percent = download ? download.percent || 0 : 0;
    return {
      width: `${percent}%`,
    }
  }

  _onDragStart = (event) => {
    const {file} = this.props
    const filePath = FileDownloadStore.pathForFile(file)
    if (fs.existsSync(filePath)) {
      // Note: From trial and error, it appears that the second param /MUST/ be the
      // same as the last component of the filePath URL, or the download fails.
      const DownloadURL = `${file.contentType}:${path.basename(filePath)}:file://${filePath}`
      event.dataTransfer.setData("DownloadURL", DownloadURL)
      event.dataTransfer.setData("text/nylas-file-url", DownloadURL)
    } else {
      event.preventDefault()
    }
  };

  _onClickView = () => {
    if (this._canClickToView()) {
      Actions.fetchAndOpenFile(this.props.file)
    }
  };

  _onClickRemove = (event) => {
    Actions.removeFile({
      file: this.props.file,
      messageClientId: this.props.messageClientId,
    })
    event.stopPropagation() // Prevent 'onClickView'
  };

  _onClickDownload = (event) => {
    Actions.fetchAndSaveFile(this.props.file)
    event.stopPropagation() // Prevent 'onClickView'
  };

  _onClickAbort = (event) => {
    Actions.abortFetchFile(this.props.file)
    event.stopPropagation() // Prevent 'onClickView'
  };

  _renderRemoveIcon() {
    return (
      <RetinaImg
        name="remove-attachment.png"
        mode={RetinaImg.Mode.ContentIsMask}
      />
    )
  }

  _renderDownloadButton() {
    return (
      <RetinaImg
        name="icon-attachment-download.png"
        mode={RetinaImg.Mode.ContentIsMask}
      />
    )
  }

  _renderFileActionIcon() {
    if (this.props.removable) {
      return (
        <div className="file-action-icon" onClick={this._onClickRemove}>
          {this._renderRemoveIcon()}
        </div>
      )
    } else if (this._isDownloading() && this._canAbortDownload()) {
      return (
        <div className="file-action-icon" onClick={this._onClickAbort}>
          {this._renderRemoveIcon()}
        </div>
      )
    }
    return (
      <div className="file-action-icon" onClick={this._onClickDownload}>
        {this._renderDownloadButton()}
      </div>
    )
  }

  render() {
    const {file, download} = this.props;
    const downloadState = download ? download.state || "" : "";

    return (
      <div className="inner" onDoubleClick={this._onClickView} onDragStart={this._onDragStart} draggable="true">
        <span className={`progress-bar-wrap state-${downloadState}`}>
          <span className="progress-background" />
          <span className="progress-foreground" style={this._downloadProgressStyle()} />
        </span>

        <Flexbox direction="row" style={{alignItems: 'center'}}>
          <div className="file-info-wrap">
            <RetinaImg
              className="file-icon"
              fallback="file-fallback.png"
              mode={RetinaImg.Mode.ContentPreserve}
              name={`file-${file.displayExtension()}.png`}
            />
            <span className="file-name">{file.displayName()}</span>
            <span className="file-size">{file.displayFileSize()}</span>
          </div>
          {this._renderFileActionIcon()}
        </Flexbox>
      </div>
    )
  }
}

export default AttachmentComponent
