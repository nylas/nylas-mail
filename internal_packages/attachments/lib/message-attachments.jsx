import React, {Component, PropTypes} from 'react'
import {Actions, Utils, FileDownloadStore} from 'nylas-exports'
import {AttachmentItem, ImageAttachmentItem} from 'nylas-component-kit'


class MessageAttachments extends Component {
  static displayName = 'MessageAttachments'

  static containerRequired = false

  static propTypes = {
    files: PropTypes.array,
    downloads: PropTypes.object,
    messageClientId: PropTypes.string,
    filePreviewPaths: PropTypes.object,
    canRemoveAttachments: PropTypes.bool,
  }

  static defaultProps = {
    downloads: {},
    filePreviewPaths: {},
  }

  onOpenAttachment = (file) => {
    Actions.fetchAndOpenFile(file)
  }

  onRemoveAttachment = (file) => {
    const {messageClientId} = this.props
    Actions.removeFile({
      file: file,
      messageClientId: messageClientId,
    })
  }

  onDownloadAttachment = (file) => {
    Actions.fetchAndSaveFile(file)
  }

  onAbortDownload = (file) => {
    Actions.abortFetchFile(file)
  }

  renderAttachment(AttachmentRenderer, file) {
    const {canRemoveAttachments, downloads, filePreviewPaths} = this.props
    const download = downloads[file.id]
    const filePath = FileDownloadStore.pathForFile(file)
    const fileIconName = `file-${file.displayExtension()}.png`
    const displayName = file.displayName()
    const displaySize = file.displayFileSize()
    const contentType = file.contentType
    const displayFilePreview = NylasEnv.config.get('core.attachments.displayFilePreview')
    const filePreviewPath = displayFilePreview ? filePreviewPaths[file.id] : null;

    return (
      <AttachmentRenderer
        key={file.id}
        focusable
        previewable
        filePath={filePath}
        download={download}
        contentType={contentType}
        displayName={displayName}
        displaySize={displaySize}
        fileIconName={fileIconName}
        filePreviewPath={filePreviewPath}
        onOpenAttachment={() => this.onOpenAttachment(file)}
        onDownloadAttachment={() => this.onDownloadAttachment(file)}
        onAbortDownload={() => this.onAbortDownload(file)}
        onRemoveAttachment={canRemoveAttachments ? () => this.onRemoveAttachment(file) : null}
      />
    )
  }

  render() {
    const {files} = this.props;
    const nonImageFiles = files.filter((f) => !Utils.shouldDisplayAsImage(f));
    const imageFiles = files.filter((f) => Utils.shouldDisplayAsImage(f));
    return (
      <div>
        {nonImageFiles.map((file) =>
          this.renderAttachment(AttachmentItem, file)
        )}
        {imageFiles.map((file) =>
          this.renderAttachment(ImageAttachmentItem, file)
        )}
      </div>
    )
  }
}

export default MessageAttachments
