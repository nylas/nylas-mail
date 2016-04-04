import React from 'react'
import SchedulerActions from '../scheduler-actions'
import {CALENDAR_ID} from '../scheduler-constants'

/**
 * Gets rendered in a CalendarEvent
 */
export default class ProposedTimeEvent extends React.Component {
  static displayName = "ProposedTimeEvent";

  static propTypes = {
    event: React.PropTypes.object,
  }

  _onMouseDown(event) {
    event.stopPropagation();
    SchedulerActions.removeProposedTime(event.target.dataset)
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
