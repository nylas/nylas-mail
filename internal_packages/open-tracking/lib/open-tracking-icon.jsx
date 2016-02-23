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
    const metadataObjs = messages.map(msg => msg.metadataForPluginId(plugin.appId)).filter(meta => meta);
    return {opened: metadataObjs.length ? metadataObjs.every(m => m.open_count > 0) : null};
  }

  _renderIcon = () => {
    if (this.state.opened == null) {
      return <span />;
    } else if (this.state.opened) {
      return (
        <RetinaImg
          url="nylas://open-tracking/assets/envelope-open-icon@2x.png"
          mode={RetinaImg.Mode.ContentIsMask} />
      );
    }
    return (
      <RetinaImg
        className="unopened"
        url="nylas://open-tracking/assets/envelope-closed-icon@2x.png"
        mode={RetinaImg.Mode.ContentIsMask} />
    );
  };

  render() {
    return (
      <div className="open-tracking-icon">
        {this._renderIcon()}
      </div>
    );
  }
}
