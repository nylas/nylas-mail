import { React, ReactDOM, PropTypes, Actions } from 'mailspring-exports';
import { RetinaImg } from 'mailspring-component-kit';
import OpenTrackingMessagePopover from './open-tracking-message-popover';
import { PLUGIN_ID } from './open-tracking-constants';

export default class OpenTrackingIcon extends React.Component {
  static displayName = 'OpenTrackingIcon';

  static propTypes = {
    thread: PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);
    this.state = this._getStateFromThread(props.thread);
  }

  componentWillReceiveProps(newProps) {
    this.setState(this._getStateFromThread(newProps.thread));
  }

  onMouseDown = () => {
    const rect = ReactDOM.findDOMNode(this).getBoundingClientRect();
    Actions.openPopover(
      <OpenTrackingMessagePopover
        message={this.state.message}
        openMetadata={this.state.message.metadataForPluginId(PLUGIN_ID)}
      />,
      { originRect: rect, direction: 'down' }
    );
  };

  _getStateFromThread(thread) {
    const messages = thread.__messages || [];

    let lastMessage = null;
    for (let i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].draft) {
        lastMessage = messages[i];
        break;
      }
    }

    if (!lastMessage) {
      return {
        message: null,
        opened: false,
        openCount: null,
        hasMetadata: false,
      };
    }

    const lastMessageMeta = lastMessage.metadataForPluginId(PLUGIN_ID);
    const hasMetadata = lastMessageMeta != null && lastMessageMeta.open_count != null;

    return {
      message: lastMessage,
      opened: hasMetadata && lastMessageMeta.open_count > 0,
      openCount: hasMetadata ? lastMessageMeta.open_count : null,
      hasMetadata: hasMetadata,
    };
  }

  _renderImage() {
    return (
      <RetinaImg
        className={this.state.opened ? 'opened' : 'unopened'}
        url="mailspring://open-tracking/assets/icon-tracking-opened@2x.png"
        mode={RetinaImg.Mode.ContentIsMask}
      />
    );
  }

  render() {
    if (!this.state.hasMetadata) return <span style={{ width: '19px' }} />;
    const openedTitle = `${this.state.openCount} open${this.state.openCount === 1 ? '' : 's'}`;
    const title = this.state.opened ? openedTitle : 'This message has not been opened';
    return (
      <div
        title={title}
        className="open-tracking-icon"
        onMouseDown={this.state.opened ? this.onMouseDown : null}
      >
        {this._renderImage()}
      </div>
    );
  }
}
