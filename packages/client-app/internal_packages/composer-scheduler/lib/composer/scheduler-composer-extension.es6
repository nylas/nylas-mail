import {
  Event,
  Actions,
  ComposerExtension,
} from 'nylas-exports'

import {PLUGIN_ID} from '../scheduler-constants'
import SchedulerActions from '../scheduler-actions'
import {prepareEvent} from './event-prep-helper'

/**
 * Inserts the set of Proposed Times into the body of the HTML email.
 *
 */
export default class SchedulerComposerExtension extends ComposerExtension {

  static TAG_NAME = "scheduler-card";

  static editingActions() {
    return [{
      action: SchedulerActions.insertNewEventCard,
      callback: SchedulerComposerExtension._insertNewEventCard,
    }, {
      action: SchedulerActions.removeEventCard,
      callback: SchedulerComposerExtension._removeEventCard,
    }]
  }

  static _removeEventCard({editor}) {
    const el = editor.rootNode.querySelector(".new-event-card-container")
    if (el) {
      el.parentNode.removeChild(el);
    }
  }

  static _insertNewEventCard({editor, actionArg}) {
    if (editor.draftClientId === actionArg.draftClientId) { return }
    if (editor.rootNode.querySelector('.new-event-card-container')) { return }
    editor.rootNode.focus()
    const containerRect = editor.rootNode.getBoundingClientRect()
    editor.insertCustomComponent("NewEventCardContainer", {
      className: "new-event-card-container",
      style: {width: containerRect.width - 44},
    })
  }

  // We must set the `preparedEvent` to be exactly what could be posted to
  // the /events endpoint of the API.
  static _cleanEventJSON(rawJSON) {
    const json = rawJSON;
    delete json.client_id;
    delete json.id;
    json.when = {
      start_time: json._start,
      end_time: json._end,
    }
    delete json._start
    delete json._end
    return json
  }

  static applyTransformsForSending({draft}) {
    const metadata = draft.metadataForPluginId(PLUGIN_ID)
    if (metadata && metadata.pendingEvent) {
      if (metadata.proposals && metadata.proposals.length > 0) {
        Actions.recordUserEvent("Meeting Times Proposed", {
          numItems: metadata.proposals.length,
        })
      } else {
        Actions.recordUserEvent("Meeting Request Scheduled")
      }
      const nextEvent = new Event().fromJSON(metadata.pendingEvent);
      const nextEventPrepared = prepareEvent(nextEvent, draft, metadata.proposals);
      metadata.pendingEvent = SchedulerComposerExtension._cleanEventJSON(nextEventPrepared.toJSON());
      metadata.uid = draft.clientId;
      draft.applyPluginMetadata(PLUGIN_ID, metadata);
    }
  }

  static unapplyTransformsForSending() {
    return;
  }
}
