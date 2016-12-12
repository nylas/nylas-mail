import moment from 'moment-round'
import {
  Event,
  Calendar,
  DatabaseStore,
} from 'nylas-exports'

import {PLUGIN_ID} from '../scheduler-constants'

export default class NewEventHelper {

  // Extra level of indirection for testing
  static now() {
    return moment()
  }

  static launchCalendarWindow(draftClientId) {
    NylasEnv.newWindow({
      title: "Calendar",
      hidden: true, // Displayed by ProposedTimePicker::componentDidMount
      windowType: "scheduler-calendar",
      windowKey: `scheduler-calendar-${draftClientId}`,
      windowProps: {draftClientId},
    });
  }

  // Sometimes we simply hide event data instead of fully destroying it.
  // This happens when users toggle the scheduler icon or cut and paste
  // the anchor in the contenteditable.
  //
  // We've kept the data on the metadata via the `RemoveEventHelper.hideEventData` method.
  //
  // If we can't find restoration data, we'll create a new event via
  // `NewEventHelper.createNewEvent`
  static restoreOrCreateEvent(session) {
    const draft = session.draft()
    const metadata = draft.metadataForPluginId(PLUGIN_ID);
    if (metadata && (metadata.hiddenPendingEvent || metadata.pendingEvent)) {
      metadata.pendingEvent = metadata.pendingEvent || metadata.hiddenPendingEvent
      metadata.proposals = metadata.proposals || metadata.hiddenProposals
      delete metadata.hiddenPendingEvent;
      delete metadata.hiddenProposals
      return session.changes.addPluginMetadata(PLUGIN_ID, metadata);
    }
    return NewEventHelper.createNewEvent(session)
  }

  static createNewEvent(session) {
    if (!session) { return Promise.reject("Need session") }
    const draft = session.draft()
    return DatabaseStore.findAll(Calendar, {accountId: draft.accountId})
    .then((allCalendars) => {
      if (allCalendars.length === 0) {
        throw new Error(`Can't create an event. The Account \
${draft.accountId} has no calendars.`);
      }

      const cals = allCalendars.filter(c => !c.readOnly);

      if (cals.length === 0) {
        NylasEnv.showErrorDialog(`This account has no editable \
calendars. We can't create an event for you. Please make sure you have an \
editable calendar with your account provider.`);
        return Promise.reject();
      }

      const start = NewEventHelper.now().ceil(30, 'minutes');
      const metadata = draft.metadataForPluginId(PLUGIN_ID) || {};
      metadata.pendingEvent = new Event({
        calendarId: cals[0].id,
        start: start.unix(),
        end: moment(start).add(1, 'hour').unix(),
      }).toJSON();
      return session.changes.addPluginMetadata(PLUGIN_ID, metadata);
    })
  }
}
