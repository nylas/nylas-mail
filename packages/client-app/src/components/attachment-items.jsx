import fs from 'fs'
import path from 'path'
import classnames from 'classnames'
import React, {Component, PropTypes} from 'react'
import ReactDOM from 'react-dom'
import {pickHTMLProps} from 'pick-react-known-prop'
import RetinaImg from './retina-img'
import Flexbox from './flexbox'
import Spinner from './spinner'


const propTypes = {
  className: PropTypes.string,
  draggable: PropTypes.bool,
  focusable: PropTypes.bool,
  previewable: PropTypes.bool,
  filePath: PropTypes.string,
  contentType: PropTypes.string,
  download: PropTypes.shape({
    state: PropTypes.string,
    percent: PropTypes.number,
  }),
  displayName: PropTypes.string,
  displaySize: PropTypes.string,
  fileIconName: PropTypes.string,
  filePreviewPath: PropTypes.string,
  onOpenAttachment: PropTypes.func,
  onRemoveAttachment: PropTypes.func,
  onDownloadAttachment: PropTypes.func,
  onAbortDownload: PropTypes.func,
};

const defaultProps = {
  draggable: true,
}

const SPACE = ' '

function ProgressBar(props) {
  const {download} = props
  const isDownloading = download ? download.state === 'downloading' : false;
  if (!isDownloading) {
    return <span />
  }
  const {state: downloadState, percent: downloadPercent} = download
  const downloadProgressStyle = {
    width: `${Math.min(downloadPercent, 97.5)}%`,
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

  _canPreview() {
    const {filePath, previewable} = this.props
    return (
      previewable &&
      process.platform === 'darwin' &&
      fs.existsSync(filePath)
    )
  }

  _previewAttachment() {
    const {filePath} = this.props
    const currentWin = NylasEnv.getCurrentWindow()
    currentWin.previewFile(filePath)
  }

  _onDragStart = (event) => {
    const {contentType, filePath} = this.props
    if (fs.existsSync(filePath)) {
      // Note: From trial and error, it appears that the second param /MUST/ be the
      // same as the last component of the filePath URL, or the download fails.
      const downloadURL = `${contentType}:${path.basename(filePath)}:file://${filePath}`
      event.dataTransfer.setData("DownloadURL", downloadURL)
      event.dataTransfer.setData("text/nylas-file-url", downloadURL)
      const fileIconImg = ReactDOM.findDOMNode(this.refs.fileIconImg)
      const rect = fileIconImg.getBoundingClientRect()
      const x = window.devicePixelRatio === 2 ? rect.height / 2 : rect.height
      const y = window.devicePixelRatio === 2 ? rect.width / 2 : rect.width
      event.dataTransfer.setDragImage(fileIconImg, x, y)
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

  _onAttachmentKeyDown = (event) => {
    if (event.key === SPACE) {
      if (!this._canPreview()) { return; }
      event.preventDefault()
      this._previewAttachment()
    }
    if (event.key === 'Escape') {
      const attachmentNode = ReactDOM.findDOMNode(this)
      if (attachmentNode) {
        attachmentNode.blur()
      }
    }
  }

  _onClickQuicklookIcon = (event) => {
    event.preventDefault()
    event.stopPropagation()
    this._previewAttachment()
  }

  render() {
    const {
      download,
      className,
      focusable,
      draggable,
      displayName,
      displaySize,
      fileIconName,
      filePreviewPath,
      ...extraProps
    } = this.props
    const classes = classnames({
      'nylas-attachment-item': true,
      'file-attachment-item': true,
      'has-preview': filePreviewPath,
      [className]: className,
    })
    const style = draggable ? {WebkitUserDrag: 'element'} : null;
    const tabIndex = focusable ? 0 : null
    const {devicePixelRatio} = window

    return (
      <div
        style={style}
        className={classes}
        tabIndex={tabIndex}
        onKeyDown={focusable ? this._onAttachmentKeyDown : null}
        {...pickHTMLProps(extraProps)}
      >
        {filePreviewPath ?
          <div className="file-thumbnail-preview">
            <img
              role="presentation"
              src={`file://${filePreviewPath}`}
              style={{zoom: (1 / devicePixelRatio)}}
            />
          </div> :
          null
        }
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
                ref="fileIconImg"
                className="file-icon"
                fallback="file-fallback.png"
                mode={RetinaImg.Mode.ContentPreserve}
                name={fileIconName}
              />
              <span className="file-name">{displayName}</span>
              <span className="file-size">{displaySize ? `(${displaySize})` : ''}</span>
              {this._canPreview() ?
                <RetinaImg
                  className="quicklook-icon"
                  name="attachment-quicklook.png"
                  mode={RetinaImg.Mode.ContentIsMask}
                  onClick={this._onClickQuicklookIcon}
                /> :
                null
              }
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
    const {className, displayName, download, ...extraProps} = this.props
    const classes = `nylas-attachment-item image-attachment-item ${className || ''}`
    return (
      <div className={classes} {...pickHTMLProps(extraProps)}>
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
