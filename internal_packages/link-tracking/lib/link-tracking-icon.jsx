import {React} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import plugin from '../package.json'

const sum = (array, extractFn) => array.reduce( (a, b) => a + extractFn(b), 0 );

export default class LinkTrackingIcon extends React.Component {

  static displayName = 'LinkTrackingIcon';

  static propTypes = {
    thread: React.PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);
    this.state = this._getStateFromThread(props.thread);
  }

  componentWillReceiveProps(newProps) {
    this.setState(this._getStateFromThread(newProps.thread));
  }

  _getStateFromThread(thread) {
    const messages = thread.metadata;
    // Pull a list of metadata for all messages
    const metadataObjs = messages.map(msg => msg.metadataForPluginId(plugin.appId)).filter(meta => meta);
    if (metadataObjs.length) {
      // If there's metadata, return the total number of link clicks in the most recent metadata
      const mostRecentMetadata = metadataObjs.pop();
      return {
        clicks: sum(mostRecentMetadata.links || [], link => link.click_count || 0),
      };
    }
    return {clicks: null};
  }


  _renderIcon = () => {
    return this.state.clicks == null ? "" : this._getIcon(this.state.clicks);
  };

  _getIcon(clicks) {
    return (<span>
      <RetinaImg
        className={clicks > 0 ? "clicked" : ""}
        name="icon-composer-linktracking.png"
        mode={RetinaImg.Mode.ContentIsMask} />
      <span className="link-click-count">{clicks > 0 ? clicks : ""}</span>
    </span>)
  }

  render() {
    return (<div className="link-tracking-icon">
      {this._renderIcon()}
    </div>)
  }
}
