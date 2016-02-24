import {React} from 'nylas-exports'
import plugin from '../package.json'

export default class LinkTrackingPanel extends React.Component {
  static displayName = 'LinkTrackingPanel';

  static propTypes = {
    message: React.PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);
    this.state = this._getStateFromMessage(props.message)
  }

  componentWillReceiveProps(newProps) {
    this.setState(this._getStateFromMessage(newProps.message));
  }

  _getStateFromMessage(message) {
    const metadata = message.metadataForPluginId(plugin.appId);
    return metadata ? {links: metadata.links} : {};
  }

  _renderContents() {
    return this.state.links.map(link => {
      return (<tr className="link-info">
        <td className="link-url">{link.originalUrl}</td>
        <td className="link-count">{link.clickCount + " clicks"}</td>
      </tr>)
    })
  }

  render() {
    if (this.state.links) {
      return (<div className="link-tracking-panel">
        <h4>Link Tracking Enabled</h4>
        <table>
          <tbody>
            {this._renderContents()}
          </tbody>
        </table>
      </div>);
    }
    return <div></div>;
  }
}
