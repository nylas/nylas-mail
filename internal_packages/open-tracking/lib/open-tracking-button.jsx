// import {DraftStore, React, Actions, NylasAPI, DatabaseStore, Message, Rx} from 'nylas-exports'
import {React} from 'nylas-exports'
import {MetadataComposerToggleButton} from 'nylas-component-kit'
import {PLUGIN_ID, PLUGIN_NAME} from './open-tracking-constants'

export default class OpenTrackingButton extends React.Component {
  static displayName = 'OpenTrackingButton';

  static propTypes = {
    draftClientId: React.PropTypes.string.isRequired,
  };

  _title(enabled) {
    const dir = enabled ? "Disable" : "Enable";
    return `${dir} read receipts`
  }

  _errorMessage(error) {
    return `Sorry, we were unable to save your read receipt settings. ${error.message}`
  }

  render() {
    return (
      <MetadataComposerToggleButton
        title={this._title}
        iconUrl="nylas://open-tracking/assets/icon-composer-eye@2x.png"
        pluginId={PLUGIN_ID}
        pluginName={PLUGIN_NAME}
        metadataKey="tracked"
        stickyToggle
        errorMessage={this._errorMessage}
        draftClientId={this.props.draftClientId} />
    )
  }
}
