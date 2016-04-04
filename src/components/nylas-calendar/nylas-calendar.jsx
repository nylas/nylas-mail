import React from 'react'
import moment from 'moment'
import WeekView from './week-view'
import MonthView from './month-view'
import CalendarDataSource from './calendar-data-source'
import {WEEK_VIEW, MONTH_VIEW} from './calendar-constants'

/**
 * Nylas Calendar
 */
export default class NylasCalendar extends React.Component {
  static displayName = "NylasCalendar";

  static propTypes = {
    /**
     * The data source that powers all of the views of the NylasCalendar
     */
    dataSource: React.PropTypes.instanceOf(CalendarDataSource).isRequired,

    /**
     * Any extra header components for each of the supported View types of
     * the NylasCalendar
     */
    headerComponents: React.PropTypes.shape({
      day: React.PropTypes.node,
      week: React.PropTypes.node,
      month: React.PropTypes.node,
      year: React.PropTypes.node,
    }),

    /**
     * Any extra footer components for each of the supported View types of
     * the NylasCalendar
     */
    footerComponents: React.PropTypes.shape({
      day: React.PropTypes.node,
      week: React.PropTypes.node,
      month: React.PropTypes.node,
      year: React.PropTypes.node,
    }),

    /**
     * The following are a set of supported interaction handlers.
     *
     * These are passed a custom set of arguments in a single object that
     * includes the `currentView` as well as things like the `time` at the
     * click coordinate.
     */
    onCalendarMouseUp: React.PropTypes.func,
    onCalendarMouseDown: React.PropTypes.func,
    onCalendarMouseMove: React.PropTypes.func,
  }

  static defaultProps = {
    headerComponents: {day: false, week: false, month: false, year: false},
    footerComponents: {day: false, week: false, month: false, year: false},
  }

  constructor(props) {
    super(props);
    this.state = {
      currentView: WEEK_VIEW,
      currentMoment: moment(),
    };
  }

  static containerStyles = {
    height: "100%",
  }

  _getCurrentViewComponent() {
    const components = {}
    components[WEEK_VIEW] = WeekView
    components[MONTH_VIEW] = MonthView
    return components[this.state.currentView]
  }

  _changeCurrentView = (currentView) => {
    this.setState({currentView});
  }

  _changeCurrentMoment = (currentMoment) => {
    this.setState({currentMoment})
  }

  render() {
    const CurrentView = this._getCurrentViewComponent();
    return (
      <div className="nylas-calendar">
        <CurrentView
          dataSource={this.props.dataSource}
          currentMoment={this.state.currentMoment}
          headerComponents={this.props.headerComponents[this.state.currentView]}
          footerComponents={this.props.footerComponents[this.state.currentView]}
          changeCurrentView={this._changeCurrentView}
          changeCurrentMoment={this._changeCurrentMoment}
          onCalendarMouseUp={this.props.onCalendarMouseUp}
          onCalendarMouseDown={this.props.onCalendarMouseDown}
          onCalendarMouseMove={this.props.onCalendarMouseMove}
        />
      </div>
    )
  }
}
