import {PLUGIN_ID} from '../scheduler-constants'

/**
 * Removing a proposed event can happen through various mechansism.
 *
 * 1. The user click the "X" on the event card
 * 2. The user re-clicks the "Proposed Event" time card
 * 3. The user removes (permanently or temporarily) the event card's
 *    anchor from the contenteditable DOM
 *
 * In scenario 1, we want to fully remove the metadata from the object.
 *
 * In scenarios 2, and 3, we want to keep a copy of the data around since
 * it's likely the user will want to at some point restore their work.
 */
export default class RemoveEventHelper {
  static deleteEventData(session) {
    session.changes.addPluginMetadata(PLUGIN_ID, {});
  }

  static hideEventData(session) {
    const draft = session.draft()
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (metadata) {
      metadata.hiddenPendingEvent = metadata.pendingEvent
      metadata.hiddenProposals = metadata.proposals
      delete metadata.pendingEvent;
      delete metadata.proposals
      session.changes.addPluginMetadata(PLUGIN_ID, metadata);
    }
  }
}
