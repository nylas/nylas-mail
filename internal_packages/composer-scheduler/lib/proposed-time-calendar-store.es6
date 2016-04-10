import _ from 'underscore'
import moment from 'moment'
import Proposal from './proposal'
import NylasStore from 'nylas-store'
import SchedulerActions from './scheduler-actions'
import {Event} from 'nylas-exports'
import {CALENDAR_ID} from './scheduler-constants'

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
    [30, 'minutes', '30 min'],
    [1, 'hour', '1 hr'],
    [1.5, 'hours', '1½ hr'],
    [2, 'hours', '2 hr'],
    [2.5, 'hours', '2½ hr'],
    [3, 'hours', '3 hr'],
  ]

  activate() {
    this._proposedTimes = []
    this._pendingSave = false;
    this._duration = this.DURATIONS[1] // 1 hr
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
      return moment(t).floor(30, 'minutes').valueOf()
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

  _onRemoveProposedTime = ({start}) => {
    const startInt = parseInt(start, 10);
    this._proposedTimes = _.filter(this._proposedTimes, (p) =>
      p.unix() < startInt || p.unix() > startInt + (30 * 60)
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
}

export default new ProposedTimeCalendarStore()
