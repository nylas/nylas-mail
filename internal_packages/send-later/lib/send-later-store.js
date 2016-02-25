/** @babel */
import NylasStore from 'nylas-store'
import {NylasAPI, Actions, Message, DatabaseStore} from 'nylas-exports'
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
    DatabaseStore.modelify(Message, [draftClientId]).then((messages)=> {
      const {accountId} = messages[0];

      NylasAPI.authPlugin(this.pluginId, PLUGIN_NAME, accountId)
      .then(()=> {
        Actions.setMetadata(messages, this.pluginId, metadata);
      })
      .catch((error)=> {
        NylasEnv.reportError(error);
        NylasEnv.showErrorDialog(`Sorry, we were unable to schedule this message. ${error.message}`);
      });
    });
  };

  recordAction(sendLaterDate, label) {
    try {
      if (sendLaterDate) {
        const min = Math.round(((new Date(sendLaterDate)).valueOf() - Date.now()) / 1000 / 60);
        Actions.recordUserEvent("Send Later", {
          sendLaterTime: min,
          optionLabel: label,
        });
      } else {
        Actions.recordUserEvent("Send Later Cancel");
      }
    } catch (e) {
      // Do nothing
    }
  }

  onSendLater = (draftClientId, sendLaterDate, label)=> {
    this.recordAction(sendLaterDate, label)
    this.setMetadata(draftClientId, {sendLaterDate});
  };

  onCancelSendLater = (draftClientId)=> {
    this.recordAction(null)
    this.setMetadata(draftClientId, {sendLaterDate: null});
  };

  deactivate = ()=> {
    this.unsubscribers.forEach(unsub => unsub());
  };
}


export default new SendLaterStore()
