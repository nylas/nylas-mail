import {DraftStore, React, Actions, NylasAPI, DatabaseStore, Message, Rx} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import plugin from '../package.json'
const PLUGIN_ID = plugin.appId;

export default class LinkTrackingButton extends React.Component {
  static displayName = 'LinkTrackingButton';

  static propTypes = {
    draftClientId: React.PropTypes.string.isRequired,
  };

  constructor(props) {
    super(props);
    this.state = {enabled: false};
  }

  componentDidMount() {
    const query = DatabaseStore.findBy(Message, {clientId: this.props.draftClientId});
    this._subscription = Rx.Observable.fromQuery(query).subscribe(this.setStateFromDraft)
  }

  componentWillUnmount() {
    this._subscription.dispose();
  }

  setStateFromDraft =(draft)=> {
    if (!draft) return;
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    this.setState({enabled: metadata ? metadata.tracked : false});
  };

  _onClick=()=> {
    const currentlyEnabled = this.state.enabled;

    // write metadata into the draft to indicate tracked state
    DraftStore.sessionForClientId(this.props.draftClientId)
      .then(session => session.draft())
      .then(draft => {
        return NylasAPI.authPlugin(PLUGIN_ID, plugin.title, draft.accountId).then(() => {
          Actions.setMetadata(draft, PLUGIN_ID, currentlyEnabled ? null : {tracked: true});
        });
      });
  };

  render() {
    const title = this.state.enabled ? "Disable" : "Enable"
    return (
      <button
        title={`${title} link tracking`}
        className={`btn btn-toolbar ${this.state.enabled ? "btn-enabled" : ""}`}
        onClick={this._onClick}>
        <RetinaImg
          url="nylas://link-tracking/assets/linktracking-icon@2x.png"
          mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    )
  }
}

