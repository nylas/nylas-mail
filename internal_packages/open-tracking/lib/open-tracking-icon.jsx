import {React} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import plugin from '../package.json'

export default class OpenTrackingIcon extends React.Component {
  static displayName = 'OpenTrackingIcon';

  static propTypes = {
    thread: React.PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);
    this.state = this._getStateFromThread(props.thread)
  }

  componentWillReceiveProps(newProps) {
    this.setState(this._getStateFromThread(newProps.thread));
  }

  _getStateFromThread(thread) {
    const messages = thread.metadata;
    if ((messages || []).length === 0) { return {opened: false, hasMetadata: false} }
    const metadataObjs = messages.map(msg => msg.metadataForPluginId(plugin.appId)).filter(meta => meta);
    return {
      hasMetadata: metadataObjs.length > 0,
      opened: metadataObjs.every(m => m.openCount > 0),
    };
  }

  _renderIcon = () => {
    if (!this.state.hasMetadata) {
      return <span />;
    }
    return this.renderImage()
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
    return (
      <div className="open-tracking-icon">
        {this._renderIcon()}
      </div>
    );
  }
}
