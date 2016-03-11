import React from 'react';
import AutoloadImagesStore from './autoload-images-store';
import Actions from './autoload-images-actions';
import {Message} from 'nylas-exports';

export default class AutoloadImagesHeader extends React.Component {
  static displayName = 'AutoloadImagesHeader';

  static propTypes = {
    message: React.PropTypes.instanceOf(Message).isRequired,
  }

  constructor(props) {
    super(props);
    this.state = {
      blocking: AutoloadImagesStore.shouldBlockImagesIn(this.props.message),
    };
  }

  componentDidMount() {
    this._unlisten = AutoloadImagesStore.listen(() => {
      const blocking = AutoloadImagesStore.shouldBlockImagesIn(this.props.message);
      if (blocking !== this.state.blocking) {
        this.setState({blocking});
      }
    });
  }

  componentWillUnmount() {
    this._unlisten();
  }

  render() {
    const {message} = this.props;
    const {blocking} = this.state;

    if (blocking === false) {
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
