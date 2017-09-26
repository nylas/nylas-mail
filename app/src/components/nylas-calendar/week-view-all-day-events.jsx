import { React, PropTypes, Utils } from 'mailspring-exports';
import CalendarEvent from './calendar-event';

/*
 * Displays the all day events across the top bar of the week event view.
 *
 * Putting this in its own component dramatically improves performance so
 * we can use `shouldComponentUpdate` to selectively re-render these
 * events.
 */
export default class WeekViewAllDayEvents extends React.Component {
  static displayName = 'WeekViewAllDayEvents';

  static propTypes = {
    end: PropTypes.number,
    start: PropTypes.number,
    height: PropTypes.number,
    minorDim: PropTypes.number,
    allDayEvents: PropTypes.array,
    allDayOverlap: PropTypes.object,
  };

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) || !Utils.isEqualReact(nextState, this.state);
  }

  render() {
    const eventComponents = this.props.allDayEvents.map(e => {
      return (
        <CalendarEvent
          event={e}
          order={this.props.allDayOverlap[e.id].order}
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
      <div className="all-day-events" style={{ height: this.props.height }}>
        {eventComponents}
      </div>
    );
  }
}
