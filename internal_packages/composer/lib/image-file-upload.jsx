import React from 'react';
import FileUpload from './file-upload';
import {RetinaImg} from 'nylas-component-kit';

export default class ImageFileUpload extends FileUpload {
  static displayName = 'ImageFileUpload';

  static propTypes = {
    uploadData: React.PropTypes.object,
  };

  _onDragStart = (event) => {
    event.preventDefault();
  }

  render() {
    return (
      <div className="file-wrap file-image-wrap file-upload">
        <div className="file-action-icon" onClick={this._onClickRemove}>
          <RetinaImg name="image-cancel-button.png" mode={RetinaImg.Mode.ContentPreserve}/>
        </div>

        <div className="file-preview">
          <div className="file-name-container">
            <div className="file-name">{this.props.upload.filename}</div>
          </div>

          <img src={this.props.upload.targetPath} onDragStart={this._onDragStart}/>
        </div>
      </div>
    );
  }
}
