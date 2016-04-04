import NylasStore from 'nylas-store'
import SchedulerActions from './scheduler-actions'
import {Event, Message, Actions, DraftStore, DatabaseStore} from 'nylas-exports'
import {PLUGIN_ID} from './scheduler-constants'

// moment-round upon require patches `moment` with new functions.
require('moment-round')

/**
 * Maintains the creation of "Proposed Times" when scheduling with people.
 *
 * The proposed times are displayed in various calendar views.
 *
 */
class ProposedTimeMainWindowStore extends NylasStore {
  activate() {
    this.unsubscribers = [
      SchedulerActions.confirmChoices.listen(this._onConfirmChoices),
    ]
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub())
  }

  /**
   * This removes the metadata on the draft and creates an `Event` on
   * `draft.events`
   */
  _convertToDraftEvent(draft) {
    const metadata = draft.metadataForPluginId(PLUGIN_ID) || {};
    return DraftStore.sessionForClientId(draft.clientId).then((session) => {
      if (metadata.pendingEvent) {
        const event = new Event().fromJSON(metadata.pendingEvent);
        session.changes.add({events: [event]});
      } else {
        session.changes.add({events: []})
      }

      delete metadata.uid
      delete metadata.proposals
      delete metadata.pendingEvent
      Actions.setMetadata(draft, PLUGIN_ID, metadata);

      return session.changes.commit()
    });
  }

  _convertToPendingEvent(draft, proposals) {
    const metadata = draft.metadataForPluginId(PLUGIN_ID) || {};
    metadata.proposals = proposals;

    // This is used to so the backend can reference which draft
    // corresponds to which sent message. The backend uses the key `uid`
    metadata.uid = draft.clientId;

    if (draft.events.length > 0) {
      return DraftStore.sessionForClientId(draft.clientId).then((session) => {
        metadata.pendingEvent = draft.events[0].toJSON();
        session.changes.add({events: []});
        return session.changes.commit().then(() => {
          Actions.setMetadata(draft, PLUGIN_ID, metadata);
        })
      });
    }
    Actions.setMetadata(draft, PLUGIN_ID, metadata);
    return Promise.resolve()
  }


  /**
   * This will bundle up and attach the choices as metadata on the draft.
   *
   * Once we attach metadata to the draft, we need to make sure we clear
   * the start and end times of the event.
   */
  _onConfirmChoices = ({proposals, draftClientId}) => {
    this._pendingSave = true;
    this.trigger();

    DatabaseStore.find(Message, draftClientId).then((draft) => {
      if (proposals.length === 0) {
        return this._convertToDraftEvent(draft)
      }
      return this._convertToPendingEvent(draft, proposals);
    })
  }
}

export default new ProposedTimeMainWindowStore()
