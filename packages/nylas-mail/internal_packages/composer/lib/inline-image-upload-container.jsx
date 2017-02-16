import React, {Component, PropTypes} from 'react';
import ReactDOM from 'react-dom';
import fs from 'fs';
import path from 'path';
import {Actions, ImageAttachmentItem} from 'nylas-component-kit'

export default class InlineImageUploadContainer extends Component {
  static displayName = 'InlineImageUploadContainer';

  static supportsPreviewWithinEditor = false;

  static propTypes = {
    draft: PropTypes.object.isRequired,
    uploadId: PropTypes.string.isRequired,
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
          const {draft, session, uploadId} = this.props;
          const buffer = new Buffer(new Uint8Array(reader.result));
          const upload = draft.uploads.find(u =>
            u.id === uploadId
          );

          const nextTargetPath = path.join(path.dirname(upload.targetPath), `edited-${Date.now()}.png`);
          fs.writeFile(nextTargetPath, buffer, (err) => {
            if (err) {
              NylasEnv.showErrorDialog(err.toString())
              return;
            }
            const img = el.querySelector('.file-preview img');
            img.style.width = `${rect.width}px`;
            img.style.height = `${rect.height}px`;
            img.src = `${img.src}?${Date.now()}`;

            fs.unlink(upload.targetPath);

            const nextUploads = [].concat(draft.uploads);
            nextUploads.forEach((u) => {
              if (u.targetPath === upload.targetPath) {
                u.targetPath = nextTargetPath;
              }
            });
            session.changes.add({uploads: nextUploads});
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
    const {draft, uploadId, isPreview} = this.props;
    const upload = draft.uploads.find(u => uploadId === u.id);

    if (!upload) {
      return (
        <span />
      );
    }
    if (isPreview) {
      return (
        <img src={`cid:${upload.id}`} alt={upload.name} />
      );
    }

    return (
      <div
        data-src={`cid:${upload.id}`}
        className="inline-image-upload-container"
        onDoubleClick={this._onGoEdit}
      >
        <ImageAttachmentItem
          className="file-upload"
          draggable={false}
          filePath={upload.targetPath}
          displayName={upload.filename}
          onRemoveAttachment={() => Actions.removeAttachment(upload)}
        />
      </div>
    )
  }
}
