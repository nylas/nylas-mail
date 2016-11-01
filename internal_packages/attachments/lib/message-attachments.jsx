import React, {Component, PropTypes} from 'react'
import {Actions, Utils, FileDownloadStore} from 'nylas-exports'
import {AttachmentItem, ImageAttachmentItem} from 'nylas-component-kit'


function getImageFiles(files) {
  return files.filter(f => Utils.shouldDisplayAsImage(f));
}

function getNonImageFiles(files) {
  return files.filter(f => !Utils.shouldDisplayAsImage(f));
}

class MessageAttachments extends Component {
  static displayName= 'MessageAttachments'

  static propTypes = {
    files: PropTypes.array,
    downloadsData: PropTypes.object,
    messageClientId: PropTypes.string,
    canRemoveAttachments: PropTypes.bool,
  }

  static defaultProps = {
    downloadsData: {},
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

  renderAttachment(AttachmentRenderer, file, download) {
    const {canRemoveAttachments} = this.props
    const filePath = FileDownloadStore.pathForFile(file)
    const fileIconName = `file-${file.displayExtension()}.png`
    const displayName = file.displayName()
    const displaySize = file.displayFileSize()
    const contentType = file.contentType

    return (
      <AttachmentRenderer
        key={file.id}
        filePath={filePath}
        download={download}
        contentType={contentType}
        displayName={displayName}
        displaySize={displaySize}
        fileIconName={fileIconName}
        onOpenAttachment={() => this.onOpenAttachment(file)}
        onDownloadAttachment={() => this.onDownloadAttachment(file)}
        onAbortDownload={() => this.onAbortDownload(file)}
        onRemoveAttachment={canRemoveAttachments ? () => this.onRemoveAttachment(file) : null}
      />
    )
  }

  render() {
    const {files, downloadsData} = this.props;
    const nonImageFiles = getNonImageFiles(files)
    const imageFiles = getImageFiles(files)
    return (
      <div>
        {nonImageFiles.map((file) =>
          this.renderAttachment(AttachmentItem, file, downloadsData[file.id])
        )}
        {imageFiles.map((file) =>
          this.renderAttachment(ImageAttachmentItem, file, downloadsData[file.id])
        )}
      </div>
    )
  }
}

export default MessageAttachments
