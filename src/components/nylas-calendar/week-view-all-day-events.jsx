import React from 'react'
import CalendarEvent from './calendar-event'
import {Utils} from 'nylas-exports'

/**
 * Displays the all day events across the top bar of the week event view.
 *
 * Putting this in its own component dramatically improves performance so
 * we can use `shouldComponentUpdate` to selectively re-render these
 * events.
 */
export default class WeekViewAllDayEvents extends React.Component {
  static displayName = "WeekViewAllDayEvents";

  static propTypes = {
    end: React.PropTypes.number,
    start: React.PropTypes.number,
    height: React.PropTypes.number,
    minorDim: React.PropTypes.number,
    allDayEvents: React.PropTypes.array,
    allDayOverlap: React.PropTypes.object,
  }

  shouldComponentUpdate(nextProps, nextState) {
    return (!Utils.isEqualReact(nextProps, this.props) ||
            !Utils.isEqualReact(nextState, this.state));
  }

  render() {
    const eventComponents = this.props.allDayEvents.map((e) => {
      return (
        <CalendarEvent event={e} order={this.props.allDayOverlap[e.id].order}
          key={e.id}
          scopeStart={this.props.start}
          scopeEnd={this.props.end}
          direction="horizontal"
          fixedSize={this.props.minorDim}
          concurrentEvents={this.props.allDayOverlap[e.id].concurrentEvents}
        />
      );
    });
    return (
      <div className="all-day-events" style={{height: this.props.height}}>
        {eventComponents}
      </div>
    )
  }
}
