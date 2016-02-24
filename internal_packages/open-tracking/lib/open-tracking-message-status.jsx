import {React} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import plugin from '../package.json'

export default class OpenTrackingMessageStatus extends React.Component {
  static displayName = "OpenTrackingMessageStatus";

  static propTypes = {
    message: React.PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);
    this.state = this._getStateFromMessage(props.message)
  }

  _getStateFromMessage(message) {
    const metadata = message.metadataForPluginId(plugin.appId);
    if (!metadata) {
      return {hasMetadata: false, opened: false}
    }
    return {
      hasMetadata: true,
      opened: metadata.openCount > 0,
    };
  }

  static containerStyles = {
    paddingTop: 4,
  };

  renderImage() {
    return (
      <RetinaImg
        className={this.state.opened ? "opened" : "unopened"}
        url="nylas://open-tracking/assets/icon-composer-eye@2x.png"
        mode={RetinaImg.Mode.ContentIsMask} />
    );
  }

  render() {
    if (!this.state.hasMetadata) { return false }
    const txt = this.state.opened ? "Read" : "Unread";
    return (
      <span className={`read-receipt-message-status ${txt}`}>{this.renderImage()}&nbsp;&nbsp;{txt}</span>
    )
  }
}
