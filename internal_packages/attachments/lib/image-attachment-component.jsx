import React, {PropTypes} from 'react'
import {RetinaImg, Spinner, DraggableImg} from 'nylas-component-kit'
import AttachmentComponent from './attachment-component'


class ImageAttachmentComponent extends AttachmentComponent {
  static displayName = 'ImageAttachmentComponent';

  static propTypes = {
    file: PropTypes.object.isRequired,
    download: PropTypes.object,
    targetPath: PropTypes.string,
  };

  static containerRequired = false;

  _canAbortDownload() {
    return false
  }

  _imgOrLoader() {
    const {download, targetPath} = this.props
    if (download && download.percent <= 5) {
      return (
        <div style={{width: "100%", height: "100px"}}>
          <Spinner visible />
        </div>
      )
    } else if (download && download.percent < 100) {
      return (
        <DraggableImg src={`${targetPath}?percent=${download.percent}`} />
      )
    }
    return <DraggableImg src={targetPath} />
  }

  _renderRemoveIcon() {
    return (
      <RetinaImg
        name="image-cancel-button.png"
        mode={RetinaImg.Mode.ContentPreserve}
      />
    )
  }

  _renderDownloadButton() {
    return (
      <RetinaImg
        name="image-download-button.png"
        mode={RetinaImg.Mode.ContentPreserve}
      />
    )
  }

  render() {
    const {download, file} = this.props
    const state = download ? download.state || "" : ""
    const displayName = file.displayName()
    return (
      <div>
        <span className={`progress-bar-wrap state-${state}`}>
          <span className="progress-background" />
          <span className="progress-foreground" style={this._downloadProgressStyle()} />
        </span>
        {this._renderFileActionIcon()}
        <div className="file-preview" onDoubleClick={this._onClickView}>
          <div className="file-name-container">
            <div className="file-name">{displayName}</div>
          </div>
          {this._imgOrLoader()}
        </div>
      </div>
    )
  }
}

export default ImageAttachmentComponent
