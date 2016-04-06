import React from 'react'
import SchedulerActions from '../scheduler-actions'
import {CALENDAR_ID} from '../scheduler-constants'

/**
 * Gets rendered in a CalendarEvent
 */
export default class ProposedTimeEvent extends React.Component {
  static displayName = "ProposedTimeEvent";

  // Since ProposedTimeEvent is part of an Injected Component set, by
  // default it's placed in its own container that's rendered separately.
  //
  // This makes two separate React trees which cause the react event
  // propagations to be separate. See:
  // https://github.com/facebook/react/issues/1691
  //
  // Unfortunately, this means that `stopPropagation` doesn't work from
  // within injected component sets unless the `containerRequired` is set
  // to `false`
  static containerRequired = false;

  static propTypes = {
    event: React.PropTypes.object,
  }

  _onMouseDown(event) {
    event.stopPropagation();
    SchedulerActions.removeProposedTime(event.target.dataset);
  }

  render() {
    if (this.props.event.calendarId === CALENDAR_ID) {
      return (
        <div className="rm-time"
          data-end={this.props.event.end}
          data-start={this.props.event.start}
          onMouseDown={this._onMouseDown}
        >&times;</div>
      )
    }
    return false
  }
}
