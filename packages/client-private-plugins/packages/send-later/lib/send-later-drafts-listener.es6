import {Rx, DatabaseStore, Message, Actions} from 'nylas-exports'
import {PLUGIN_ID} from './send-later-constants'

class SendLaterDraftsListener {

  constructor() {
    this._disposable = {dispose: () => {}}
  }

  activate() {
    if (!NylasEnv.isMainWindow()) { return }
    const query = DatabaseStore
      .findAll(Message)
      .order(Message.attributes.date.descending())
      .where({draft: true})
      .where(Message.attributes.pluginMetadata.contains(PLUGIN_ID))
    const observable = Rx.Observable.fromQuery(query);
    this._disposable = observable.subscribe(this._onSendLaterDraftsChanged)
  }

  _onSendLaterDraftsChanged = (drafts) => {
    drafts.forEach((draft) => {
      const metadatum = draft.metadataForPluginId(PLUGIN_ID)
      if (!metadatum) { return }
      const {expiration, cancelled} = metadatum
      if (!expiration && !cancelled) {
        Actions.destroyDraft(draft.clientId)
      }
    })
  }

  deactivate() {
    this._disposable.dispose()
  }
}

export default new SendLaterDraftsListener()
