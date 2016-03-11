/** @babel */
import NylasStore from 'nylas-store'
import {
  NylasAPI,
  Actions,
  Message,
  DatabaseStore,
  SyncbackDraftTask,
} from 'nylas-exports'
import SendLaterActions from './send-later-actions'
import {PLUGIN_ID, PLUGIN_NAME} from './send-later-constants'


class SendLaterStore extends NylasStore {

  constructor(pluginId = PLUGIN_ID, pluginName = PLUGIN_NAME) {
    super()
    this.pluginId = pluginId;
    this.pluginName = pluginName;
  }

  activate() {
    this.unsubscribers = [
      SendLaterActions.sendLater.listen(this.onSendLater),
      SendLaterActions.cancelSendLater.listen(this.onCancelSendLater),
    ];
  }

  setMetadata = (draftClientId, metadata)=> {
    return DatabaseStore.modelify(Message, [draftClientId])
    .then((messages)=> {
      const {accountId} = messages[0];

      return NylasAPI.authPlugin(this.pluginId, this.pluginName, accountId)
      .then(()=> {
        Actions.setMetadata(messages, this.pluginId, metadata);

        // Important: Do not remove this unless N1 is syncing drafts by default.
        Actions.queueTask(new SyncbackDraftTask(draftClientId));
      })
      .catch((error)=> {
        NylasEnv.reportError(error);
        NylasEnv.showErrorDialog(`Sorry, we were unable to schedule this message. ${error.message}`);
      });
    });
  };

  recordAction(sendLaterDate, dateLabel) {
    try {
      if (sendLaterDate) {
        const min = Math.round(((new Date(sendLaterDate)).valueOf() - Date.now()) / 1000 / 60);
        Actions.recordUserEvent("Send Later", {
          sendLaterTime: min,
          optionLabel: dateLabel,
        });
      } else {
        Actions.recordUserEvent("Send Later Cancel");
      }
    } catch (e) {
      // Do nothing
    }
  }

  onSendLater = (draftClientId, sendLaterDate, dateLabel)=> {
    this.recordAction(sendLaterDate, dateLabel)
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

export default SendLaterStore
