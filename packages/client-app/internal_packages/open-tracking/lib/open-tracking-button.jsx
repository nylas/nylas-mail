// import {DraftStore, React, Actions, NylasAPI, DatabaseStore, Message, Rx} from 'nylas-exports'
import {React, APIError, NylasAPI} from 'nylas-exports'
import {MetadataComposerToggleButton} from 'nylas-component-kit'
import {PLUGIN_ID, PLUGIN_NAME} from './open-tracking-constants'

export default class OpenTrackingButton extends React.Component {
  static displayName = 'OpenTrackingButton';

  static propTypes = {
    draft: React.PropTypes.object.isRequired,
    session: React.PropTypes.object.isRequired,
  };

  shouldComponentUpdate(nextProps) {
    return (nextProps.draft.metadataForPluginId(PLUGIN_ID) !== this.props.draft.metadataForPluginId(PLUGIN_ID));
  }

  _title(enabled) {
    const dir = enabled ? "Disable" : "Enable";
    return `${dir} open tracking`
  }

  _errorMessage(error) {
    if (error instanceof APIError && NylasAPI.TimeoutErrorCodes.includes(error.statusCode)) {
      return `Open tracking does not work offline. Please re-enable when you come back online.`
    }
    return `Unfortunately, open tracking is currently not available. Please try again later. Error: ${error.message}`
  }

  render() {
    const enabledValue = {
      open_count: 0,
      open_data: [],
    };

    return (
      <MetadataComposerToggleButton
        title={this._title}
        iconUrl="nylas://open-tracking/assets/icon-composer-eye@2x.png"
        pluginId={PLUGIN_ID}
        pluginName={PLUGIN_NAME}
        metadataEnabledValue={enabledValue}
        stickyToggle
        errorMessage={this._errorMessage}
        draft={this.props.draft}
        session={this.props.session}
      />
    )
  }
}

OpenTrackingButton.containerRequired = false;
