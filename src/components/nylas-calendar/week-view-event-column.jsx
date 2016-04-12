import React from 'react'
import moment from 'moment'
import classnames from 'classnames'
import CalendarEvent from './calendar-event'
import {Utils} from 'nylas-exports'

/**
 * This display a single column of events in the Week View.
 * Putting it in its own component dramatically improves render
 * performance since we can run `shouldComponentUpdate` on a
 * column-by-column basis.
 */
export default class WeekViewEventColumn extends React.Component {
  static displayName = "WeekViewEventColumn";

  static propTypes = {
    events: React.PropTypes.array.isRequired,
    day: React.PropTypes.instanceOf(moment),
    dayEnd: React.PropTypes.number,
    eventOverlap: React.PropTypes.object,
  }

  shouldComponentUpdate(nextProps, nextState) {
    return (!Utils.isEqualReact(nextProps, this.props) ||
            !Utils.isEqualReact(nextState, this.state));
  }

  _eventComponents() {
    return this.props.events.map((e) => {
      return (
        <CalendarEvent event={e} order={this.props.eventOverlap[e.id].order}
          key={e.id}
          scopeEnd={this.props.dayEnd}
          scopeStart={this.props.day.unix()}
          concurrentEvents={this.props.eventOverlap[e.id].concurrentEvents}/>
      );
    });
  }

  render() {
    const className = classnames({
      "event-column": true,
      "weekend": this.props.day.day() === 0 || this.props.day.day() === 6,
    });
    const end = moment(this.props.day).add(1, 'day').subtract(1, 'millisecond').valueOf()
    return (
      <div className={className} key={this.props.day.valueOf()}
           data-start={this.props.day.valueOf()} data-end={end}>
        {this._eventComponents()}
      </div>
    )
  }
}
