import {React} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import {PLUGIN_ID} from './open-tracking-constants'

export default class OpenTrackingMessageStatus extends React.Component {
  static displayName = "OpenTrackingMessageStatus";

  static propTypes = {
    message: React.PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);
    this.state = this._getStateFromMessage(props.message)
  }

  componentWillReceiveProps(nextProps) {
    this.setState(this._getStateFromMessage(nextProps.message))
  }

  _getStateFromMessage(message) {
    const metadata = message.metadataForPluginId(PLUGIN_ID);
    if (!metadata || metadata.open_count == null) {
      return {hasMetadata: false, opened: false}
    }
    return {
      hasMetadata: true,
      opened: metadata.open_count > 0,
    };
  }

  static containerStyles = {
    paddingTop: 4,
  };

  renderImage() {
    return (
      <RetinaImg
        className={this.state.opened ? "opened" : "unopened"}
        style={{position: 'relative', top: -1}}
        url="nylas://open-tracking/assets/InMessage-Read@2x.png"
        mode={RetinaImg.Mode.ContentIsMask} />
    );
  }

  render() {
    if (!this.state.hasMetadata) { return false }
    const txt = this.state.opened ? "Read" : "Unread";
    const title = this.state.opened ? "This message has been read at least once" : "This message has not been read";
    return (
      <span title={title} className={`read-receipt-message-status ${txt}`}>{this.renderImage()}&nbsp;&nbsp;{txt}</span>
    )
  }
}
