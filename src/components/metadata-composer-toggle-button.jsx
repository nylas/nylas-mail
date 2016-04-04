import {DraftStore, React, Actions, NylasAPI, APIError, DatabaseStore, Message, Rx} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import classnames from 'classnames'

export default class MetadataComposerToggleButton extends React.Component {

  static displayName = 'MetadataComposerToggleButton';

  static propTypes = {
    title: React.PropTypes.func.isRequired,
    iconUrl: React.PropTypes.string,
    iconName: React.PropTypes.string,
    pluginId: React.PropTypes.string.isRequired,
    pluginName: React.PropTypes.string.isRequired,
    metadataEnabledValue: React.PropTypes.object.isRequired,
    stickyToggle: React.PropTypes.bool,
    errorMessage: React.PropTypes.func.isRequired,
    draftClientId: React.PropTypes.string.isRequired,
  };

  static defaultProps = {
    stickyToggle: false,
  };

  constructor(props) {
    super(props);
    this.state = {
      enabled: false,
      isSetup: false,
    };
  }

  componentDidMount() {
    this._mounted = true;
    const query = DatabaseStore.findBy(Message, {clientId: this.props.draftClientId});
    this._subscription = Rx.Observable.fromQuery(query).subscribe(this._onDraftChange)
  }

  componentWillUnmount() {
    this._mounted = false
    this._subscription.dispose();
  }

  _configKey() {
    return `plugins.${this.props.pluginId}.defaultOn`
  }

  _isDefaultOn() {
    return NylasEnv.config.get(this._configKey())
  }

  _onDraftChange = (draft)=> {
    if (!this._mounted || !draft) { return; }
    const metadata = draft.metadataForPluginId(this.props.pluginId);
    if (!metadata) {
      if (!this.state.isSetup) {
        if (this._isDefaultOn()) {
          this._setEnabled(true)
        }
        this.setState({isSetup: true})
      }
    } else {
      this.setState({enabled: true, isSetup: true});
    }
  };

  _setEnabled(enabled) {
    const metadataValue = enabled ? this.props.metadataEnabledValue : null;
    this.setState({enabled, pending: true});

    return DraftStore.sessionForClientId(this.props.draftClientId).then((session)=> {
      const draft = session.draft();

      return NylasAPI.authPlugin(this.props.pluginId, this.props.pluginName, draft.accountId)
      .then(() => {
        Actions.setMetadata(draft, this.props.pluginId, metadataValue);
      })
      .catch((error) => {
        this.setState({enabled: false});

        if (this.props.stickyToggle) {
          NylasEnv.config.set(this._configKey(), false)
        }

        let title = "Error"
        if (!(error instanceof APIError)) {
          NylasEnv.reportError(error);
        } else if (error.statusCode === 400) {
          NylasEnv.reportError(error);
        } else if (NylasAPI.TimeoutErrorCodes.includes(error.statusCode)) {
          title = "Offline"
        }

        NylasEnv.showErrorDialog({title, message: this.props.errorMessage(error)});
      })
    }).finally(() => {
      this.setState({pending: false})
    });
  }

  _onClick = () => {
    // Toggle.
    if (this.state.pending) { return; }
    const dir = this.state.enabled ? "Disabled" : "Enabled"
    Actions.recordUserEvent(`${this.props.pluginName} ${dir}`)
    if (this.props.stickyToggle) {
      NylasEnv.config.set(this._configKey(), !this.state.enabled)
    }
    this._setEnabled(!this.state.enabled)
  };

  render() {
    const title = this.props.title(this.state.enabled)

    const className = classnames({
      "btn": true,
      "btn-toolbar": true,
      "btn-pending": this.state.pending,
      "btn-enabled": this.state.enabled,
    });

    const attrs = {}
    if (this.props.iconUrl) {
      attrs.url = this.props.iconUrl
    } else if (this.props.iconName) {
      attrs.name = this.props.iconName
    }

    return (
      <button className={className} onClick={this._onClick} title={title} tabIndex={-1}>
        <RetinaImg {...attrs} mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }

}
