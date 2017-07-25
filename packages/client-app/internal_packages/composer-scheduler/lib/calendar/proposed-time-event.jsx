import React from 'react'
import classnames from 'classnames'
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

  _onMouseDown(event) {
    event.stopPropagation();
    SchedulerActions.removeProposedTime(event.target.dataset);
  }

  render() {
    const className = classnames({
      "rm-time": true,
      "proposal": this.props.event.proposalType === "proposal",
      "availability": this.props.event.proposalType === "availability",
    });
    if (this.props.event.calendarId === CALENDAR_ID) {
      return (
        <div
          className={className}
          data-end={this.props.event.end}
          data-start={this.props.event.start}
          onMouseDown={this._onMouseDown}
        >&times;</div>
      )
    }
    return false
  }
}
