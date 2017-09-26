import { React, ReactDOM, Actions, PropTypes } from 'mailspring-exports';
import { RetinaImg } from 'mailspring-component-kit';
import OpenTrackingMessagePopover from './open-tracking-message-popover';
import { PLUGIN_ID } from './open-tracking-constants';

export default class OpenTrackingMessageStatus extends React.Component {
  static displayName = 'OpenTrackingMessageStatus';

  static propTypes = {
    message: PropTypes.object.isRequired,
  };

  static containerStyles = {
    paddingTop: 4,
  };

  constructor(props) {
    super(props);
    this.state = this._getStateFromMessage(props.message);
  }

  componentWillReceiveProps(nextProps) {
    this.setState(this._getStateFromMessage(nextProps.message));
  }

  onMouseDown = () => {
    const rect = ReactDOM.findDOMNode(this).getBoundingClientRect();
    Actions.openPopover(
      <OpenTrackingMessagePopover
        message={this.props.message}
        openMetadata={this.props.message.metadataForPluginId(PLUGIN_ID)}
      />,
      { originRect: rect, direction: 'down' }
    );
  };

  _getStateFromMessage(message) {
    const metadata = message.metadataForPluginId(PLUGIN_ID);
    if (!metadata || metadata.open_count == null) {
      return {
        hasMetadata: false,
        openCount: null,
        opened: false,
      };
    }
    return {
      hasMetadata: true,
      openCount: metadata.open_count,
      opened: metadata.open_count > 0,
    };
  }

  renderImage() {
    return (
      <RetinaImg
        className={this.state.opened ? 'opened' : 'unopened'}
        style={{ position: 'relative', top: -1 }}
        url="mailspring://open-tracking/assets/InMessage-opened@2x.png"
        mode={RetinaImg.Mode.ContentIsMask}
      />
    );
  }

  render() {
    if (!this.state.hasMetadata) return false;
    let openedCount = `${this.state.openCount} open${this.state.openCount === 1 ? '' : 's'}`;
    if (this.state.openCount > 999) openedCount = '999+ opens';
    const text = this.state.opened ? openedCount : 'No opens';
    return (
      <span
        className={`open-tracking-message-status ${this.state.opened ? 'opened' : 'unopened'}`}
        onMouseDown={this.state.opened ? this.onMouseDown : null}
      >
        {this.renderImage()}&nbsp;&nbsp;{text}
      </span>
    );
  }
}
