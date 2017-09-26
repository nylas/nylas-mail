import { React, PropTypes, APIError, NylasAPIRequest } from 'nylas-exports';
import { MetadataComposerToggleButton } from 'nylas-component-kit';
import { PLUGIN_ID, PLUGIN_NAME } from './link-tracking-constants';

export default class LinkTrackingButton extends React.Component {
  static displayName = 'LinkTrackingButton';

  static propTypes = {
    draft: PropTypes.object.isRequired,
    session: PropTypes.object.isRequired,
  };

  shouldComponentUpdate(nextProps) {
    return (
      nextProps.draft.metadataForPluginId(PLUGIN_ID) !==
      this.props.draft.metadataForPluginId(PLUGIN_ID)
    );
  }

  _title(enabled) {
    const dir = enabled ? 'Disable' : 'Enable';
    return `${dir} link tracking`;
  }

  _errorMessage(error) {
    if (error instanceof APIError && NylasAPIRequest.TimeoutErrorCodes.includes(error.statusCode)) {
      return `Link tracking does not work offline. Please re-enable when you come back online.`;
    }
    return `Unfortunately, link tracking servers are currently not available. Please try again later. Error: ${error.message}`;
  }

  render() {
    return (
      <MetadataComposerToggleButton
        title={this._title}
        iconName="icon-composer-linktracking.png"
        pluginId={PLUGIN_ID}
        pluginName={PLUGIN_NAME}
        metadataEnabledValue={{ tracked: true }}
        stickyToggle
        errorMessage={this._errorMessage}
        draft={this.props.draft}
        session={this.props.session}
      />
    );
  }
}

LinkTrackingButton.containerRequired = false;
