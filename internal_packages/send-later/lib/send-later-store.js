/** @babel */
import NylasStore from 'nylas-store'
import {NylasAPI, Actions, Message, Rx, DatabaseStore} from 'nylas-exports'
import SendLaterActions from './send-later-actions'
import {PLUGIN_ID, PLUGIN_NAME} from './send-later-constants'


class SendLaterStore extends NylasStore {

  constructor(pluginId = PLUGIN_ID) {
    super()
    this.pluginId = pluginId;
  }

  activate() {
    this.unsubscribers = [
      SendLaterActions.sendLater.listen(this.onSendLater),
      SendLaterActions.cancelSendLater.listen(this.onCancelSendLater),
    ];
  }

  getScheduledDateForMessage = (message)=> {
    if (!message) {
      return null;
    }
    const metadata = message.metadataForPluginId(this.pluginId) || {};
    return metadata.sendLaterDate || null;
  };

  setMetadata = (draftClientId, metadata)=> {
    return (
      DatabaseStore.modelify(Message, [draftClientId])
      .then((messages)=> {
        const {accountId} = messages[0];
        return NylasAPI.authPlugin(this.pluginId, PLUGIN_NAME, accountId);
      })
      .then(()=> {
        Actions.setMetadata(messages, this.pluginId, metadata);
      })
      .catch((error)=> {
        NylasEnv.reportError(error);
        NylasEnv.showErrorDialog(`Sorry, we were unable to schedule this message. ${error.message}`);
      })
    );
  };

  onSendLater = (draftClientId, sendLaterDate)=> {
    this.setMetadata(draftClientId, {sendLaterDate})
  };

  onCancelSendLater = (draftClientId)=> {
    this.setMetadata(draftClientId, {sendLaterDate: null})
  };

  deactivate = ()=> {
    this.unsubscribers.forEach(unsub => unsub())
  };
}


export default new SendLaterStore()
