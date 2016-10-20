import _ from 'underscore'
import moment from 'moment'
import React from 'react'
import ReactTestUtils from 'react-addons-test-utils'
import {NylasCalendar} from 'nylas-component-kit'

import {
  now,
  NOW_WEEK_START,
  NOW_BUFFER_START,
  NOW_BUFFER_END,
} from './test-utils'

import TestDataSource from './test-data-source'
import {
  numByDay,
  numAllDayEvents,
  numStandardEvents,
  eventOverlapForSunday,
} from './fixtures/events'

import WeekView from '../../../src/components/nylas-calendar/week-view'

describe("Nylas Calendar Week View", function weekViewSpec() {
  beforeEach(() => {
    spyOn(WeekView.prototype, "_now").andReturn(now());

    this.onCalendarMouseDown = jasmine.createSpy("onCalendarMouseDown")
    this.dataSource = new TestDataSource();
    this.calendar = ReactTestUtils.renderIntoDocument(
      <NylasCalendar
        currentMoment={now()}
        onCalendarMouseDown={this.onCalendarMouseDown}
        dataSource={this.dataSource}
      />
    );
    this.weekView = ReactTestUtils.findRenderedComponentWithType(this.calendar, WeekView);
  });

  it("renders a calendar", () => {
    const cal = ReactTestUtils.findRenderedComponentWithType(this.calendar, NylasCalendar)
    expect(cal instanceof NylasCalendar).toBe(true)
  });

  it("sets the correct moment", () => {
    expect(this.calendar.state.currentMoment.valueOf()).toBe(now().valueOf())
  });

  it("defaulted to WeekView", () => {
    expect(this.calendar.state.currentView).toBe("week");
    expect(this.weekView instanceof WeekView).toBe(true);
  });

  it("initializes the component", () => {
    expect(this.weekView.todayYear).toBe(now().year());
    expect(this.weekView.todayDayOfYear).toBe(now().dayOfYear());
  });

  it("initializes the data source & state with the correct times", () => {
    expect(this.dataSource.startTime).toBe(NOW_BUFFER_START.unix());
    expect(this.dataSource.endTime).toBe(NOW_BUFFER_END.unix());
    expect(this.weekView.state.startMoment.unix()).toBe(NOW_BUFFER_START.unix());
    expect(this.weekView.state.endMoment.unix()).toBe(NOW_BUFFER_END.unix());
    expect(this.weekView._scrollTime).toBe(NOW_WEEK_START.unix())
  });

  it("has the correct days in buffer", () => {
    const days = this.weekView._daysInView();
    expect(days.length).toBe(21);
    expect(days[0].dayOfYear()).toBe(66)
    expect(days[days.length - 1].dayOfYear()).toBe(86)
  });

  it("shows the correct current week", () => {
    expect(this.weekView._currentWeekText()).toBe("March 13 - March 19 2016")
  });

  it("goes to next week on click", () => {
    const nextBtn = this.weekView.refs.headerControls.refs.onNextAction
    expect(this.weekView.state.startMoment.unix()).toBe(NOW_BUFFER_START.unix());
    expect(this.weekView._scrollTime).toBe(NOW_WEEK_START.unix())

    ReactTestUtils.Simulate.click(nextBtn);

    expect((this.weekView.state.startMoment).unix())
      .toBe(moment(NOW_BUFFER_START).add(1, 'week').unix());

    expect(this.weekView._scrollTime)
      .toBe(moment(NOW_WEEK_START).add(1, 'week').unix());
  });

  it("goes to the previous week on click", () => {
    const prevBtn = this.weekView.refs.headerControls.refs.onPreviousAction
    expect(this.weekView.state.startMoment.unix()).toBe(NOW_BUFFER_START.unix());
    expect(this.weekView._scrollTime).toBe(NOW_WEEK_START.unix())

    ReactTestUtils.Simulate.click(prevBtn);

    expect((this.weekView.state.startMoment).unix())
      .toBe(moment(NOW_BUFFER_START).subtract(1, 'week').unix());

    expect(this.weekView._scrollTime)
      .toBe(moment(NOW_WEEK_START).subtract(1, 'week').unix());
  });

  it("goes to 'today' when the 'today' btn is pressed", () => {
    const todayBtn = this.weekView.refs.todayBtn;
    const nextBtn = this.weekView.refs.headerControls.refs.onNextAction
    ReactTestUtils.Simulate.click(nextBtn);
    ReactTestUtils.Simulate.click(todayBtn)

    expect(this.weekView.state.startMoment.unix()).toBe(NOW_BUFFER_START.unix());
    expect(this.weekView._scrollTime).toBe(NOW_WEEK_START.unix())
  });

  it("sets the interval height properly", () => {
    expect(this.weekView.state.intervalHeight).toBe(21)
  });

  it("properly segments the events by day", () => {
    const days = this.weekView._daysInView();
    const eventsByDay = this.weekView._eventsByDay(days);

    // See fixtures/events
    expect(eventsByDay.allDay.length).toBe(numAllDayEvents);
    for (const day of Object.keys(numByDay)) {
      expect(eventsByDay[day].length).toBe(numByDay[day])
    }
  });

  it("correctly stacks all day events", () => {
    const height = this.weekView.refs.weekViewAllDayEvents.props.height;
    // This means it's 3-high
    expect(height).toBe(64);
  });

  it("correctly sets up the event overlap for a day", () => {
    const days = this.weekView._daysInView();
    const eventsByDay = this.weekView._eventsByDay(days);
    const eventOverlap = this.weekView._eventOverlap(eventsByDay['1457856000']);
    expect(eventOverlap).toEqual(eventOverlapForSunday)
  });

  it("renders the events onto the grid", () => {
    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass, this.weekView);

    const events = $("calendar-event");
    const standardEvents = $("calendar-event vertical");
    const allDayEvents = $("calendar-event horizontal");

    expect(events.length).toBe(numStandardEvents + numAllDayEvents)
    expect(standardEvents.length).toBe(numStandardEvents)
    expect(allDayEvents.length).toBe(numAllDayEvents)
  });

  it("finds the correct data from mouse events", () => {
    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass, this.weekView);

    const eventContainer = this.weekView.refs.calendarEventContainer;

    // Unfortunately, _dataFromMouseEvent requires the component to both
    // be mounted and have size. To truly test this we'd have to load the
    // integratino test environment. For now, we test that the event makes
    // its way back to passed in callback handlers
    const mouseData = {
      x: 100,
      y: 100,
      width: 100,
      height: 100,
      time: now(),
    }
    spyOn(eventContainer, "_dataFromMouseEvent").andReturn(mouseData)

    const eventEl = $("calendar-event vertical")[0];
    ReactTestUtils.Simulate.mouseDown(eventEl, {x: 100, y: 100});

    const mouseEvent = eventContainer._dataFromMouseEvent.calls[0].args[0];
    expect(mouseEvent.x).toBe(100)
    expect(mouseEvent.y).toBe(100)

    const mouseDataOut = this.onCalendarMouseDown.calls[0].args[0]
    expect(mouseDataOut.x).toEqual(mouseData.x)
    expect(mouseDataOut.y).toEqual(mouseData.y)
    expect(mouseDataOut.width).toEqual(mouseData.width)
    expect(mouseDataOut.height).toEqual(mouseData.height)
    expect(mouseDataOut.time.unix()).toEqual(mouseData.time.unix())
  });
});
