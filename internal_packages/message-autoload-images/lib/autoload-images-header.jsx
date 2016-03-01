import React from 'react';
import AutoloadImagesStore from './autoload-images-store';
import Actions from './autoload-images-actions';
import {Message} from 'nylas-exports';

export default class AutoloadImagesHeader extends React.Component {
  static displayName = 'AutoloadImagesHeader';

  static propTypes = {
    message: React.PropTypes.instanceOf(Message).isRequired,
  }

  render() {
    const {message} = this.props;

    if (AutoloadImagesStore.shouldBlockImagesIn(message) === false) {
      return (
        <div></div>
      );
    }

    return (
      <div className="autoload-images-header">
        <a className="option" onClick={ ()=> Actions.temporarilyEnableImages(message) }>
          Show Images
        </a>
        <span style={{paddingLeft: 10, paddingRight: 10}}>|</span>
        <a className="option" onClick={ ()=> Actions.permanentlyEnableImages(message) }>
          Always show images from {message.fromContact().toString()}
        </a>
      </div>
    );
  }
}
