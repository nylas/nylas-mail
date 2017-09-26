import {
  React,
  PropTypes,
  Actions,
  MailspringAPIRequest,
  NylasAPIHelpers,
  APIError,
} from 'mailspring-exports';
import { RetinaImg } from 'mailspring-component-kit';
import classnames from 'classnames';
import _ from 'underscore';

export default class MetadataComposerToggleButton extends React.Component {
  static displayName = 'MetadataComposerToggleButton';

  static propTypes = {
    title: PropTypes.func.isRequired,
    iconUrl: PropTypes.string,
    iconName: PropTypes.string,
    pluginId: PropTypes.string.isRequired,
    pluginName: PropTypes.string.isRequired,
    metadataEnabledValue: PropTypes.object.isRequired,
    stickyToggle: PropTypes.bool,
    errorMessage: PropTypes.func.isRequired,

    draft: PropTypes.object.isRequired,
    session: PropTypes.object.isRequired,
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
    return `plugins.${this.props.pluginId}.defaultOn`;
  }

  _isEnabled() {
    const { pluginId, draft, metadataEnabledValue } = this.props;
    const value = draft.metadataForPluginId(pluginId);
    return _.isEqual(value, metadataEnabledValue) || _.isMatch(value, metadataEnabledValue);
  }

  _isEnabledByDefault() {
    return AppEnv.config.get(this._configKey()) !== false;
  }

  async _setEnabled(enabled) {
    const { pluginId, pluginName, draft, session, metadataEnabledValue } = this.props;

    const metadataValue = enabled ? metadataEnabledValue : null;
    this.setState({ pending: true });

    try {
      session.changes.addPluginMetadata(pluginId, metadataValue);
    } catch (error) {
      const { stickyToggle, errorMessage } = this.props;

      if (stickyToggle) {
        AppEnv.config.set(this._configKey(), false);
      }

      let title = 'Error';
      if (!(error instanceof APIError)) {
        AppEnv.reportError(error);
      } else if (error.statusCode === 400) {
        AppEnv.reportError(error);
      } else if (MailspringAPIRequest.TimeoutErrorCodes.includes(error.statusCode)) {
        title = 'Offline';
      }

      AppEnv.showErrorDialog({ title, message: errorMessage(error) });
    }

    this.setState({ pending: false });
  }

  _onClick = () => {
    if (this.state.pending) {
      return;
    }

    const enabled = this._isEnabled();
    const dir = enabled ? 'Disabled' : 'Enabled';
    Actions.recordUserEvent(`${this.props.pluginName} ${dir}`);
    if (this.props.stickyToggle) {
      AppEnv.config.set(this._configKey(), !enabled);
    }
    this._setEnabled(!enabled);
  };

  render() {
    const enabled = this._isEnabled();
    const title = this.props.title(enabled);

    const className = classnames({
      btn: true,
      'btn-toolbar': true,
      'btn-pending': this.state.pending,
      'btn-enabled': enabled,
    });

    const attrs = {};
    if (this.props.iconUrl) {
      attrs.url = this.props.iconUrl;
    } else if (this.props.iconName) {
      attrs.name = this.props.iconName;
    }

    return (
      <button className={className} onClick={this._onClick} title={title} tabIndex={-1}>
        <RetinaImg {...attrs} mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }
}
