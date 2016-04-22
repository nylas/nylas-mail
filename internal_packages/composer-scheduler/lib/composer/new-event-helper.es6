import moment from 'moment'
import {PLUGIN_ID} from '../scheduler-constants'

import {
  Event,
  Calendar,
  DatabaseStore,
} from 'nylas-exports'

export default class NewEventHelper {

  // Extra level of indirection for testing
  static now() {
    return moment()
  }

  static launchCalendarWindow(draftClientId) {
    NylasEnv.newWindow({
      title: "Calendar",
      hidden: true, // Displayed by ProposedTimePicker::componentDidMount
      windowType: "calendar",
      windowProps: {draftClientId},
    });
  }

  static addEventToSession(session) {
    if (!session) { return }
    const draft = session.draft()
    DatabaseStore.findAll(Calendar, {accountId: draft.accountId})
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
        return;
      }

      const start = NewEventHelper.now().ceil(30, 'minutes');
      const metadata = draft.metadataForPluginId(PLUGIN_ID) || {};
      metadata.uid = draft.clientId;
      metadata.pendingEvent = new Event({
        calendarId: cals[0].id,
        start: start.unix(),
        end: moment(start).add(1, 'hour').unix(),
      }).toJSON();
      session.changes.addPluginMetadata(PLUGIN_ID, metadata);
    })
  }
}
