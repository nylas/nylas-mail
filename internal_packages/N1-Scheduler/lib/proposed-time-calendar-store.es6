import _ from 'underscore'
import NylasStore from 'nylas-store'
import moment from 'moment'
import Proposal from './proposal'
import SchedulerActions from './scheduler-actions'
import {Event, Message, Actions, DraftStore, DatabaseStore} from 'nylas-exports'
import {PLUGIN_ID, CALENDAR_ID} from './scheduler-constants'

// moment-round upon require patches `moment` with new functions.
require('moment-round')

/**
 * Maintains the creation of "Proposed Times" when scheduling with people.
 *
 * The proposed times are displayed in various calendar views.
 *
 */
class ProposedTimeCalendarStore extends NylasStore {
  DURATIONS = [
    [15, 'minutes', '15 min'],
    [30, 'minutes', '30 min'],
    [50, 'minutes', '50 min'],
    [1, 'hour', '1 hr'],
    [1.5, 'hours', '1½ hr'],
    [2, 'hours', '2 hr'],
    [2.5, 'hours', '2½ hr'],
    [3, 'hours', '3 hr'],
  ]

  activate() {
    this._proposedTimes = []
    this._pendingSave = false;
    // this.triggerLater = _.throttle(this.trigger, 32)
    this._duration = this.DURATIONS[3] // 1 hr
    this.unsubscribers = [
      SchedulerActions.changeDuration.listen(this._onChangeDuration),
      SchedulerActions.addProposedTime.listen(this._onAddProposedTime),
      SchedulerActions.removeProposedTime.listen(this._onRemoveProposedTime),
    ]
  }

  pendingSave() {
    return this._pendingSave
  }

  deactivate() {
    this.unsubscribers.forEach(unsub => unsub())
  }

  currentDuration() {
    return this._duration
  }

  timeBlocks() {
    return _.groupBy(this._proposedTimes, (t) => {
      const blockSize = this._duration.slice(0, 2)
      return moment(t).floor(blockSize[0], blockSize[1]).valueOf()
    })
  }

  timeBlocksAsEvents() {
    const blockSize = this._duration.slice(0, 2)
    return _.map(this.timeBlocks(), (data, start) =>
      new Event().fromJSON({
        title: "Proposed Time",
        calendar_id: CALENDAR_ID,
        when: {
          object: "timespan",
          start_time: moment(+start).unix(),
          end_time: moment(+start).add(blockSize[0], blockSize[1]).subtract(1, 'second').unix(),
        },
      })
    );
  }

  /**
   * Gets called with a new time as the user drags their mouse across the
   * event grid. This gets called on every mouse move and mouseup.
   */
  _onAddProposedTime = (newMoment) => {
    this._proposedTimes.push(newMoment);
    this.trigger()
  }

  _onChangeDuration = (newDuration) => {
    this._duration = newDuration
    this.trigger()
  }

  _onRemoveProposedTime = ({start, end}) => {
    this._proposedTimes = _.filter(this._proposedTimes, (p) =>
      p.unix() < start || p.unix() > end
    )
    this.trigger()
  }

  timeBlocksAsProposals() {
    return this.timeBlocksAsEvents().map((e) =>
      new Proposal({
        start: e.start,
        end: e.end,
      })
    )
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
  _onConfirmChoices = (proposals) => {
    this._pendingSave = true;
    this.trigger();

    const {draftClientId} = NylasEnv.getWindowProps();

    DatabaseStore.find(Message, draftClientId).then((draft) => {
      if (proposals.length === 0) {
        return this._convertToDraftEvent(draft)
      }
      return this._convertToPendingEvent(draft, proposals);
    })
  }
}

export default new ProposedTimeCalendarStore()
