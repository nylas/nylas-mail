import path from 'path';
import React from 'react';
import {RetinaImg, Flexbox} from 'nylas-component-kit';
import {
  Actions,
} from 'nylas-exports';

export default class FileUpload extends React.Component {
  static displayName = 'FileUpload';

  static propTypes = {
    upload: React.PropTypes.object,
  };

  _onClickRemove = (event) => {
    event.preventDefault();
    Actions.removeAttachment(this.props.upload);
  }

  _extension = () => {
    const ext = path.extname(this.props.upload.filename.toLowerCase())
    return ext.slice(1); // remove leading .
  }

  render() {
    return (
      <div className="file-wrap file-upload">
        <div className="inner">
          <Flexbox direction="row" style={{alignItems: 'center'}}>
            <div className="file-info-wrap">
              <RetinaImg
                className="file-icon"
                fallback="file-fallback.png"
                mode={RetinaImg.Mode.ContentPreserve}
                name={`file-${this._extension()}.png`}
              />
              <span className="file-name">
                <span className="uploading">
                  {this.props.upload.filename}
                </span>
              </span>
            </div>
            <div className="file-action-icon" onClick={this._onClickRemove}>
              <RetinaImg
                name="remove-attachment.png"
                mode={RetinaImg.Mode.ContentIsMask}
              />
            </div>
          </Flexbox>
        </div>
      </div>
    );
  }
}
