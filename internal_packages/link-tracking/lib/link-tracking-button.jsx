// import {DraftStore, React, Actions, NylasAPI, DatabaseStore, Message, Rx} from 'nylas-exports'
import {React, APIError, NylasAPI} from 'nylas-exports'
import {MetadataComposerToggleButton} from 'nylas-component-kit'
import {PLUGIN_ID, PLUGIN_NAME} from './link-tracking-constants'

export default class LinkTrackingButton extends React.Component {
  static displayName = 'LinkTrackingButton';

  static propTypes = {
    draftClientId: React.PropTypes.string.isRequired,
  };

  _title(enabled) {
    const dir = enabled ? "Disable" : "Enable";
    return `${dir} link tracking`
  }

  _errorMessage(error) {
    if (error instanceof APIError && error.statusCode === NylasAPI.TimeoutErrorCode) {
      return `Link tracking does not work offline. Please re-enable when you come back online.`
    }
    return `Unfortunately, link tracking servers are currently not available. Please try again later.`
  }

  render() {
    return (
      <MetadataComposerToggleButton
        title={this._title}
        iconName="icon-composer-linktracking.png"
        pluginId={PLUGIN_ID}
        pluginName={PLUGIN_NAME}
        metadataKey="tracked"
        stickyToggle
        errorMessage={this._errorMessage}
        draftClientId={this.props.draftClientId} />
    )
  }
}
