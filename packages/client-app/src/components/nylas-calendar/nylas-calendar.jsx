import Rx from 'rx-lite'
import React from 'react'
import moment from 'moment'
import {DatabaseStore, AccountStore, Calendar} from 'nylas-exports'
import {ScrollRegion, ResizableRegion, MiniMonthView} from 'nylas-component-kit'
import WeekView from './week-view'
import MonthView from './month-view'
import EventSearchBar from './event-search-bar'
import CalendarToggles from './calendar-toggles'
import CalendarDataSource from './calendar-data-source'
import {WEEK_VIEW, MONTH_VIEW} from './calendar-constants'

const DISABLED_CALENDARS = "nylas.disabledCalendars"

/*
 * Nylas Calendar
 */
export default class NylasCalendar extends React.Component {
  static displayName = "NylasCalendar";

  static propTypes = {
    /*
     * The data source that powers all of the views of the NylasCalendar
     */
    dataSource: React.PropTypes.instanceOf(CalendarDataSource).isRequired,

    currentMoment: React.PropTypes.instanceOf(moment),

    /*
     * Any extra info you want to display on the top banner of calendar
     * components
     */
    bannerComponents: React.PropTypes.shape({
      day: React.PropTypes.node,
      week: React.PropTypes.node,
      month: React.PropTypes.node,
      year: React.PropTypes.node,
    }),

    /*
     * Any extra header components for each of the supported View types of
     * the NylasCalendar
     */
    headerComponents: React.PropTypes.shape({
      day: React.PropTypes.node,
      week: React.PropTypes.node,
      month: React.PropTypes.node,
      year: React.PropTypes.node,
    }),

    /*
     * Any extra footer components for each of the supported View types of
     * the NylasCalendar
     */
    footerComponents: React.PropTypes.shape({
      day: React.PropTypes.node,
      week: React.PropTypes.node,
      month: React.PropTypes.node,
      year: React.PropTypes.node,
    }),

    /*
     * The following are a set of supported interaction handlers.
     *
     * These are passed a custom set of arguments in a single object that
     * includes the `currentView` as well as things like the `time` at the
     * click coordinate.
     */
    onCalendarMouseUp: React.PropTypes.func,
    onCalendarMouseDown: React.PropTypes.func,
    onCalendarMouseMove: React.PropTypes.func,

    onEventClick: React.PropTypes.func,
    onEventDoubleClick: React.PropTypes.func,
    onEventFocused: React.PropTypes.func,

    selectedEvents: React.PropTypes.arrayOf(React.PropTypes.object),
  }

  static defaultProps = {
    bannerComponents: {day: false, week: false, month: false, year: false},
    headerComponents: {day: false, week: false, month: false, year: false},
    footerComponents: {day: false, week: false, month: false, year: false},
    selectedEvents: [],
  }

  static containerStyles = {
    height: "100%",
  }

  constructor(props) {
    super(props);
    this.state = {
      calendars: [],
      focusedEvent: null,
      currentView: WEEK_VIEW,
      currentMoment: props.currentMoment || this._now(),
      disabledCalendars: NylasEnv.config.get(DISABLED_CALENDARS) || [],
    };
  }

  componentWillMount() {
    this._disposable = this._subscribeToCalendars()
  }

  componentWillUnmount() {
    this._disposable.dispose()
  }

  _subscribeToCalendars() {
    const calQuery = DatabaseStore.findAll(Calendar)
    const calQueryObs = Rx.Observable.fromQuery(calQuery)
    const accQueryObs = Rx.Observable.fromStore(AccountStore)
    const configObs = Rx.Observable.fromConfig(DISABLED_CALENDARS)
    return Rx.Observable.combineLatest([calQueryObs, accQueryObs, configObs])
    .subscribe(([calendars, accountStore, disabledCalendars]) => {
      this.setState({
        accounts: accountStore.accounts() || [],
        calendars: calendars || [],
        disabledCalendars: disabledCalendars || [],
      })
    })
  }

  _now() {
    return moment()
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
    this.setState({currentMoment, focusedEvent: null})
  }

  _changeCurrentMomentFromValue = (value) => {
    this.setState({currentMoment: moment(value), focusedEvent: null})
  }

  _focusEvent = (event) => {
    const value = event.start * 1000
    this.setState({currentMoment: moment(value), focusedEvent: event})
  }

  render() {
    const CurrentView = this._getCurrentViewComponent();
    return (
      <div className="nylas-calendar">
        <ResizableRegion
          className="calendar-toggles"
          initialWidth={200}
          minWidth={200}
          maxWidth={300}
          handle={ResizableRegion.Handle.Right}
          style={{flexDirection: 'column'}}
        >
          <ScrollRegion style={{flex: 1}}>
            <EventSearchBar
              onSelectEvent={this._focusEvent}
              disabledCalendars={this.state.disabledCalendars}
            />
            <CalendarToggles
              accounts={this.state.accounts}
              calendars={this.state.calendars}
              disabledCalendars={this.state.disabledCalendars}
            />
          </ScrollRegion>
          <div style={{width: "100%"}}>
            <MiniMonthView
              value={this.state.currentMoment.valueOf()}
              onChange={this._changeCurrentMomentFromValue}
            />
          </div>

        </ResizableRegion>
        <CurrentView
          dataSource={this.props.dataSource}
          currentMoment={this.state.currentMoment}
          focusedEvent={this.state.focusedEvent}
          bannerComponents={this.props.bannerComponents[this.state.currentView]}
          headerComponents={this.props.headerComponents[this.state.currentView]}
          footerComponents={this.props.footerComponents[this.state.currentView]}
          changeCurrentView={this._changeCurrentView}
          disabledCalendars={this.state.disabledCalendars}
          changeCurrentMoment={this._changeCurrentMoment}
          onCalendarMouseUp={this.props.onCalendarMouseUp}
          onCalendarMouseDown={this.props.onCalendarMouseDown}
          onCalendarMouseMove={this.props.onCalendarMouseMove}
          selectedEvents={this.props.selectedEvents}
          onEventClick={this.props.onEventClick}
          onEventDoubleClick={this.props.onEventDoubleClick}
          onEventFocused={this.props.onEventFocused}
        />
      </div>
    )
  }
}


NylasCalendar.WeekView = WeekView;
