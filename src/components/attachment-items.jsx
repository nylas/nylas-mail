import fs from 'fs'
import path from 'path'
import React, {Component, PropTypes} from 'react'
import ReactDOM from 'react-dom'
import RetinaImg from './retina-img'
import Flexbox from './flexbox'
import Spinner from './spinner'


const propTypes = {
  className: PropTypes.string,
  draggable: PropTypes.bool,
  filePath: PropTypes.string,
  contentType: PropTypes.string,
  download: PropTypes.shape({
    state: PropTypes.string,
    percent: PropTypes.number,
  }),
  displayName: PropTypes.string,
  displaySize: PropTypes.string,
  fileIconName: PropTypes.string,
  onOpenAttachment: PropTypes.func,
  onRemoveAttachment: PropTypes.func,
  onDownloadAttachment: PropTypes.func,
  onAbortDownload: PropTypes.func,
};

const defaultProps = {
  draggable: true,
}

function ProgressBar(props) {
  const {download} = props
  if (!download) {
    return <span />
  }
  const {state: downloadState, percent: downloadPercent} = download
  const downloadProgressStyle = {
    width: `${downloadPercent}%`,
  }
  return (
    <span className={`progress-bar-wrap state-${downloadState}`}>
      <span className="progress-background" />
      <span className="progress-foreground" style={downloadProgressStyle} />
    </span>
  )
}
ProgressBar.propTypes = propTypes


function AttachmentActionIcon(props) {
  const {
    download,
    removeIcon,
    downloadIcon,
    retinaImgMode,
    onAbortDownload,
    onRemoveAttachment,
    onDownloadAttachment,
  } = props

  const isRemovable = onRemoveAttachment != null
  const isDownloading = download ? download.state === 'downloading' : false;
  const actionIconName = isRemovable || isDownloading ? removeIcon : downloadIcon;

  const onClickActionIcon = (event) => {
    event.stopPropagation() // Prevent 'onOpenAttachment'
    if (isRemovable) {
      onRemoveAttachment()
    } else if (isDownloading && onAbortDownload != null) {
      onAbortDownload()
    } else if (onDownloadAttachment != null) {
      onDownloadAttachment()
    }
  }

  return (
    <div className="file-action-icon" onClick={onClickActionIcon}>
      <RetinaImg
        name={actionIconName}
        mode={retinaImgMode}
      />
    </div>
  )
}
AttachmentActionIcon.propTypes = {
  removeIcon: PropTypes.string,
  downloadIcon: PropTypes.string,
  retinaImgMode: PropTypes.string,
  ...propTypes,
}


export class AttachmentItem extends Component {
  static displayName = 'AttachmentItem';

  static containerRequired = false;

  static propTypes = propTypes;

  static defaultProps = defaultProps;

  _onDragStart = (event) => {
    const {contentType, filePath} = this.props
    if (fs.existsSync(filePath)) {
      // Note: From trial and error, it appears that the second param /MUST/ be the
      // same as the last component of the filePath URL, or the download fails.
      const DownloadURL = `${contentType}:${path.basename(filePath)}:file://${filePath}`
      event.dataTransfer.setData("DownloadURL", DownloadURL)
      event.dataTransfer.setData("text/nylas-file-url", DownloadURL)
    } else {
      event.preventDefault()
    }
  };

  _onOpenAttachment = () => {
    const {onOpenAttachment} = this.props
    if (onOpenAttachment != null) {
      onOpenAttachment()
    }
  };

  render() {
    const {
      download,
      className,
      draggable,
      displayName,
      displaySize,
      fileIconName,
    } = this.props
    const classes = `nylas-attachment-item ${className}`
    const style = draggable ? {WebkitUserDrag: 'element'} : null;

    return (
      <div className={classes} style={style}>
        <div
          className="inner"
          draggable={draggable}
          onDoubleClick={this._onOpenAttachment}
          onDragStart={this._onDragStart}
        >
          <ProgressBar download={download} />
          <Flexbox direction="row" style={{alignItems: 'center'}}>
            <div className="file-info-wrap">
              <RetinaImg
                className="file-icon"
                fallback="file-fallback.png"
                mode={RetinaImg.Mode.ContentPreserve}
                name={fileIconName}
              />
              <span className="file-name">{displayName}</span>
              <span className="file-size">{displaySize}</span>
            </div>
            <AttachmentActionIcon
              {...this.props}
              removeIcon="remove-attachment.png"
              downloadIcon="icon-attachment-download.png"
              retinaImgMode={RetinaImg.Mode.ContentIsMask}
            />
          </Flexbox>
        </div>
      </div>
    )
  }
}


export class ImageAttachmentItem extends Component {
  static displayName = 'ImageAttachmentItem';

  static propTypes = {
    imgProps: PropTypes.object,
    ...propTypes,
  };

  static defaultProps = defaultProps;

  static containerRequired = false;

  _onOpenAttachment = () => {
    const {onOpenAttachment} = this.props
    if (onOpenAttachment != null) {
      onOpenAttachment()
    }
  };

  _onImgLoaded = () => {
    // on load, modify our DOM just /slightly/. This causes DOM mutation listeners
    // watching the DOM to trigger. This is a good thing, because the image may
    // change dimensions. (We use this to reflow the draft body when this component
    // is within an OverlaidComponent)
    const el = ReactDOM.findDOMNode(this);
    if (el) {
      el.classList.add('loaded');
    }
  }

  renderImage() {
    const {download, filePath, draggable} = this.props
    if (download && download.percent <= 5) {
      return (
        <div style={{width: "100%", height: "100px"}}>
          <Spinner visible />
        </div>
      )
    }
    const src = download && download.percent < 100 ? `${filePath}?percent=${download.percent}` : filePath;
    return (
      <img draggable={draggable} src={src} role="presentation" onLoad={this._onImgLoaded} />
    )
  }

  render() {
    const {className, displayName, download} = this.props
    const classes = `nylas-attachment-item image-attachment-item ${className}`
    return (
      <div className={classes}>
        <div>
          <ProgressBar download={download} />
          <AttachmentActionIcon
            {...this.props}
            removeIcon="image-cancel-button.png"
            downloadIcon="image-download-button.png"
            retinaImgMode={RetinaImg.Mode.ContentPreserve}
            onAbortDownload={null}
          />
          <div className="file-preview" onDoubleClick={this._onOpenAttachment}>
            <div className="file-name-container">
              <div className="file-name">{displayName}</div>
            </div>
            {this.renderImage()}
          </div>
        </div>
      </div>
    )
  }
}
