/** @babel */
import NylasStore from 'nylas-store'
import {NylasAPI, Actions, Message, Rx, DatabaseStore} from 'nylas-exports'
import SendLaterActions from './send-later-actions'
import {PLUGIN_ID, PLUGIN_NAME} from './send-later-constants'


class SendLaterStore extends NylasStore {

  constructor(pluginId = PLUGIN_ID) {
    super()
    this.pluginId = pluginId
    this.scheduledMessages = new Map()
  }

  activate() {
    this.setupQuerySubscription()

    this.unsubscribers = [
      SendLaterActions.sendLater.listen(this.onSendLater),
      SendLaterActions.cancelSendLater.listen(this.onCancelSendLater),
    ]
  }

  setupQuerySubscription() {
    const query = DatabaseStore.findAll(
      Message, [Message.attributes.pluginMetadata.contains(this.pluginId)]
    )
    this.queryDisposable = Rx.Observable.fromQuery(query).subscribe(this.onScheduledMessagesChanged)
  }

  getScheduledMessage = (messageClientId)=> {
    return this.scheduledMessages.get(messageClientId)
  };

  isScheduled = (messageClientId)=> {
    const message = this.getScheduledMessage(messageClientId)
    if (message && message.metadataForPluginId(this.pluginId).sendLaterDate) {
      return true
    }
    return false
  };

  setMetadata = (draftClientId, metadata)=> {
    return (
      DatabaseStore.modelify(Message, [draftClientId])
      .then((messages)=> {
        const {accountId} = messages[0]
        return NylasAPI.authPlugin(this.pluginId, PLUGIN_NAME, accountId)
        .then(()=> {
          Actions.setMetadata(messages, this.pluginId, metadata)
        })
        .catch((error)=> {
          console.error(error)
          NylasEnv.showErrorDialog(error.message)
        })
      })
    )
  };

  onScheduledMessagesChanged = (messages)=> {
    this.scheduledMessages.clear()
    messages.forEach((message)=> {
      this.scheduledMessages.set(message.clientId, message);
    })
    this.trigger()
  };

  onSendLater = (draftClientId, sendLaterDate)=> {
    this.setMetadata(draftClientId, {sendLaterDate})
  };

  onCancelSendLater = (draftClientId)=> {
    this.setMetadata(draftClientId, {sendLaterDate: null})
  };

  deactivate = ()=> {
    this.queryDisposable.dispose()
    this.unsubscribers.forEach(unsub => unsub())
  };
}


export default new SendLaterStore()
