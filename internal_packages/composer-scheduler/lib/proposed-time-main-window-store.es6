import NylasStore from 'nylas-store'
import SchedulerActions from './scheduler-actions'
import {Message, Actions, DatabaseStore} from 'nylas-exports'
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
   * This will bundle up and attach the choices as metadata on the draft.
   *
   * Once we attach metadata to the draft, we need to make sure we clear
   * the start and end times of the event.
   */
  _onConfirmChoices = ({proposals = [], draftClientId}) => {
    this._pendingSave = true;
    this.trigger();

    DatabaseStore.find(Message, draftClientId).then((draft) => {
      const metadata = draft.metadataForPluginId(PLUGIN_ID) || {};
      if (proposals.length === 0) {
        delete metadata.proposals
      } else {
        metadata.proposals = proposals;
      }
      Actions.setMetadata(draft, PLUGIN_ID, metadata);
    })
  }
}

export default new ProposedTimeMainWindowStore()
