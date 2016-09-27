import {React, Actions, NylasAPI, APIError} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import classnames from 'classnames'
import _ from 'underscore'

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

    draft: React.PropTypes.object.isRequired,
    session: React.PropTypes.object.isRequired,
  };

  static defaultProps = {
    stickyToggle: false,
  };

  constructor(props) {
    super(props);

    this.state = {
      pending: false,
    };
  }

  componentWillMount() {
    if (this._isEnabledByDefault() && !this._isEnabled()) {
      this._setEnabled(true);
    }
  }

  _configKey() {
    return `plugins.${this.props.pluginId}.defaultOn`
  }

  _isEnabled() {
    const {pluginId, draft, metadataEnabledValue} = this.props;
    const value = draft.metadataForPluginId(pluginId);
    return _.isEqual(value, metadataEnabledValue) || _.isMatch(value, metadataEnabledValue);
  }

  _isEnabledByDefault() {
    return NylasEnv.config.get(this._configKey()) !== false;
  }

  _setEnabled(enabled) {
    const {pluginId, pluginName, draft, session, metadataEnabledValue} = this.props;

    const metadataValue = enabled ? metadataEnabledValue : null;
    this.setState({pending: true});

    NylasAPI.authPlugin(pluginId, pluginName, draft.accountId)
    .then(() => {
      session.changes.addPluginMetadata(pluginId, metadataValue);
    })
    .catch((error) => {
      const {stickyToggle, errorMessage} = this.props;

      if (stickyToggle) {
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

      NylasEnv.showErrorDialog({title, message: errorMessage(error)});
    }).finally(() => {
      this.setState({pending: false})
    });
  }

  _onClick = () => {
    if (this.state.pending) { return; }

    const enabled = this._isEnabled();
    const dir = enabled ? "Disabled" : "Enabled"
    Actions.recordUserEvent(`${this.props.pluginName} ${dir}`)
    if (this.props.stickyToggle) {
      NylasEnv.config.set(this._configKey(), !enabled);
    }
    this._setEnabled(!enabled);
  };

  render() {
    const enabled = this._isEnabled();
    const title = this.props.title(enabled);

    const className = classnames({
      "btn": true,
      "btn-toolbar": true,
      "btn-pending": this.state.pending,
      "btn-enabled": enabled,
    });

    const attrs = {}
    if (this.props.iconUrl) {
      attrs.url = this.props.iconUrl
    } else if (this.props.iconName) {
      attrs.name = this.props.iconName
    }

    return (
      <button
        className={className}
        onClick={this._onClick}
        title={title}
        tabIndex={-1}
      >
        <RetinaImg {...attrs} mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }

}
