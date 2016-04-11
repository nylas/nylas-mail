import _ from 'underscore'
import moment from 'moment'
import Proposal from './proposal'
import NylasStore from 'nylas-store'
import SchedulerActions from './scheduler-actions'
import {Event, Utils} from 'nylas-exports'
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
    this._proposals = []
    this._resetDragBuffer();
    this._pendingSave = false;
    this._duration = this.DURATIONS[0] // 30 min
    this.unsubscribers = [
      SchedulerActions.changeDuration.listen(this._onChangeDuration),
      SchedulerActions.clearProposals.listen(this._onClearProposals),
      SchedulerActions.addToProposedTimeBlock.listen(this._onAddToBlock),
      SchedulerActions.startProposedTimeBlock.listen(this._onStartBlock),
      SchedulerActions.endProposedTimeBlock.listen(this._onEndBlock),
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

  _dragBufferAsEvent() {
    if (!this._dragBuffer.anchor) {
      return []
    }
    const {start, end} = this._dragBuffer
    return [new Event().fromJSON({
      title: "Availability Block",
      calendar_id: CALENDAR_ID,
      when: {
        object: "timespan",
        start_time: start,
        end_time: end,
      },
    })];
  }

  proposalsAsEvents() {
    return _.map(this._proposals, (p) =>
      new Event().fromJSON({
        title: "Proposed Time",
        calendar_id: CALENDAR_ID,
        when: {
          object: "timespan",
          start_time: p.start,
          end_time: p.end,
        },
      })
    ).concat(this._dragBufferAsEvent());
  }

  _convertBufferToProposedTimes() {
    const bounds = this._dragBuffer;
    const minMoment = moment.unix(bounds.start);
    minMoment.floor(30, 'minutes');

    const maxMoment = moment.unix(bounds.end);
    maxMoment.ceil(30, 'minutes');

    if (maxMoment.isSameOrBefore(minMoment)) { return }

    this._proposals = _.reject(this._proposals, (p) =>
      Utils.overlapsBounds(bounds, p)
    )

    const blockSize = this._duration.slice(0, 2)
    blockSize[0] = parseInt(blockSize[0], 10);
    const isMinBlockSize = (bounds.end - bounds.start) >= moment.duration.apply(moment, blockSize).as('seconds');
    while (minMoment.isSameOrBefore(maxMoment)) {
      const start = minMoment.unix();
      minMoment.add(blockSize[0], blockSize[1]);
      const end = minMoment.unix() - 1;
      if (end >= bounds.end && isMinBlockSize) { break; }
      this._proposals.push(new Proposal({start, end}))
    }
  }

  _resetDragBuffer() {
    this._dragBuffer = {
      anchor: null,
      start: Number.MAX_SAFE_INTEGER,
      end: 0,
    }
  }

  _updateDragBuffer(newT) {
    const {anchor, start, end} = this._dragBuffer
    this._dragBuffer = {
      anchor,
      start: Math.min(newT.unix(), anchor),
      end: Math.max(newT.unix(), anchor),
    }
    if (this._dragBuffer.start !== start || this._dragBuffer.end !== end) {
      this.trigger()
    }
  }

  _onStartBlock = (newT) => {
    this._resetDragBuffer();
    this._dragBuffer.anchor = newT.floor(30, 'minutes').unix()
  }

  _onAddToBlock = (newT) => {
    this._updateDragBuffer(newT.round(30, 'minutes'));
  }

  _onEndBlock = (newT) => {
    this._updateDragBuffer(newT.ceil(30, 'minutes'));
    this._convertBufferToProposedTimes()
    this._resetDragBuffer();
    this.trigger()
  }

  _onChangeDuration = (newDuration) => {
    this._duration = newDuration
    this.trigger()
  }

  _onClearProposals = () => {
    this._proposals = [];
    this.trigger();
  }

  _onRemoveProposedTime = ({start}) => {
    const startInt = parseInt(start, 10);
    this._proposals = _.reject(this._proposals, (p) =>
      p.start <= startInt && p.end > startInt
    )
    this.trigger()
  }

  proposals() {
    return this._proposals
  }
}

export default new ProposedTimeCalendarStore()
