import React, {Component, PropTypes} from 'react';
import ReactDOM from 'react-dom';
import fs from 'fs';
import path from 'path';
import {Actions, FileDownloadStore} from 'nylas-exports'
import {ImageAttachmentItem} from 'nylas-component-kit'

export default class InlineImageUploadContainer extends Component {
  static displayName = 'InlineImageUploadContainer';

  static supportsPreviewWithinEditor = false;

  static propTypes = {
    draft: PropTypes.object.isRequired,
    fileId: PropTypes.string.isRequired,
    session: PropTypes.object,
    isPreview: PropTypes.bool,
  }

  _onGoEdit = () => {
    if (!this.props.session) {
      console.warn("InlineImage editor cannot be activated, `session` prop not present. (isPreview?)")
      return;
    }
    // This is just a fun temporary hack because I was jealous of Apple Mail.
    //
    const el = ReactDOM.findDOMNode(this);
    const rect = el.getBoundingClientRect();

    const editorEl = document.createElement('div');
    editorEl.style.position = 'absolute';
    editorEl.style.left = `${rect.left}px`;
    editorEl.style.top = `${rect.top}px`;
    editorEl.style.width = `${rect.width}px`;
    editorEl.style.height = `${rect.height}px`;
    editorEl.style.zIndex = 2000;

    const editorCanvas = document.createElement('canvas');
    editorCanvas.width = rect.width * window.devicePixelRatio;
    editorCanvas.height = rect.height * window.devicePixelRatio;
    editorCanvas.style.width = `${rect.width}px`;
    editorCanvas.style.height = `${rect.height}px`;
    editorEl.appendChild(editorCanvas);

    const editorCtx = editorCanvas.getContext("2d");
    editorCtx.drawImage(el.querySelector('.file-preview img'), 0, 0, editorCanvas.width, editorCanvas.height);
    editorCtx.strokeStyle = "#df4b26";
    editorCtx.lineJoin = "round";
    editorCtx.lineWidth = 3 * window.devicePixelRatio;

    let penDown = false;
    let penXY = null;
    editorCanvas.addEventListener('mousedown', (event) => {
      penDown = true;
      penXY = {
        x: event.offsetX,
        y: event.offsetY,
      }
    });
    editorCanvas.addEventListener('mousemove', (event) => {
      if (penDown) {
        const nextPenXY = {
          x: event.offsetX,
          y: event.offsetY,
        }
        editorCtx.beginPath();
        editorCtx.moveTo(penXY.x * window.devicePixelRatio, penXY.y * window.devicePixelRatio);
        editorCtx.lineTo(nextPenXY.x * window.devicePixelRatio, nextPenXY.y * window.devicePixelRatio);
        editorCtx.closePath();
        editorCtx.stroke();
        penXY = nextPenXY;
      }
    });

    editorCanvas.addEventListener('mouseup', () => {
      penDown = false;
      penXY = null;
    });

    const backgroundEl = document.createElement('div');
    backgroundEl.style.background = 'rgba(0,0,0,0.4)';
    backgroundEl.style.position = 'absolute';
    backgroundEl.style.top = '0px';
    backgroundEl.style.left = '0px';
    backgroundEl.style.right = '0px';
    backgroundEl.style.bottom = '0px';
    backgroundEl.style.zIndex = 1999;
    backgroundEl.addEventListener('click', () => {
      editorCanvas.toBlob((blob) => {
        const reader = new FileReader();
        reader.addEventListener('loadend', () => {
          const {draft, session, fileId} = this.props;
          const buffer = new Buffer(new Uint8Array(reader.result));
          const file = draft.files.find(u =>
            u.id === fileId
          );

          const filepath = FileDownloadStore.pathForFile(file);
          const nextFileName = `edited-${Date.now()}.png`;
          const nextFilePath = path.join(path.dirname(filepath), nextFileName);

          fs.writeFile(nextFilePath, buffer, (err) => {
            if (err) {
              NylasEnv.showErrorDialog(err.toString())
              return;
            }
            const img = el.querySelector('.file-preview img');
            img.style.width = `${rect.width}px`;
            img.style.height = `${rect.height}px`;
            img.src = `${img.src}?${Date.now()}`;

            fs.unlink(filepath);

            const nextFiles = [].concat(draft.files);
            nextFiles.forEach((f) => {
              if (f.id === file.id) {
                f.filename = nextFileName;
              }
            });
            session.changes.add({files: nextFiles});
          });
        });
        reader.readAsArrayBuffer(blob);
      });
      document.body.removeChild(editorEl);
      document.body.removeChild(backgroundEl);
    });
    document.body.appendChild(backgroundEl);
    document.body.appendChild(editorEl);
  }

  render() {
    const {draft, fileId, isPreview} = this.props;
    const file = draft.files.find(u => fileId === u.id);

    if (!file) {
      return (
        <span />
      );
    }
    if (isPreview) {
      return (
        <img src={`cid:${file.id}`} alt={file.name} />
      );
    }

    return (
      <div
        data-src={`cid:${file.id}`}
        className="inline-image-upload-container"
        onDoubleClick={this._onGoEdit}
      >
        <ImageAttachmentItem
          className="file-upload"
          draggable={false}
          filePath={FileDownloadStore.pathForFile(file)}
          displayName={file.filename}
          onRemoveAttachment={() => Actions.removeAttachment(draft.headerMessageId, file)}
        />
      </div>
    )
  }
}
