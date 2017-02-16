import _ from 'underscore'
import React from 'react'
import ReactDOM from 'react-dom'
import ReactTestUtils from 'react-addons-test-utils'
import {NylasCalendar} from 'nylas-component-kit'
import {WorkspaceStore} from 'nylas-exports'

import ProposedTimePicker from '../lib/calendar/proposed-time-picker'
import TestProposalDataSource from './test-proposal-data-source'
import ProposedTimeCalendarStore from '../lib/proposed-time-calendar-store'
import {activate, deactivate} from '../lib/main'

const WeekView = NylasCalendar.WeekView;
const now = window.testNowMoment

/**
 * This tests the ProposedTimePicker as an integration test of the picker,
 * associated calendar object, the ProposedTimeCalendarStore, and stubbed
 * ProposedTimeCalendarDataSource
 *
 */
describe('ProposedTimePicker', function proposedTimePicker() {
  beforeEach(() => {
    WorkspaceStore.defineSheet('Main', {root: true},
      {popout: ['Center']})
    spyOn(NylasEnv, "getWindowType").andReturn("scheduler-calendar");
    spyOn(WeekView.prototype, "_now").andReturn(now());
    spyOn(NylasCalendar.prototype, "_now").andReturn(now());
    activate()

    this.testSrc = new TestProposalDataSource()
    spyOn(ProposedTimePicker.prototype, "_dataSource").andReturn(this.testSrc)
    this.picker = ReactTestUtils.renderIntoDocument(
      <ProposedTimePicker />
    )
    this.weekView = ReactTestUtils.findRenderedComponentWithType(this.picker, WeekView);
  });

  afterEach(() => {
    deactivate()
  })

  it("renders a proposed time picker in week view", () => {
    const picker = ReactTestUtils.findRenderedComponentWithType(this.picker, ProposedTimePicker);
    const weekView = ReactTestUtils.findRenderedComponentWithType(this.picker, WeekView);
    expect(picker instanceof ProposedTimePicker).toBe(true);
    expect(weekView instanceof WeekView).toBe(true);
  });

  // NOTE: We manually fire the SchedulerActions since we've tested the
  // mouse click to time conversion in the nylas-calendar

  it("creates a proposal on click", () => {
    this.picker._onCalendarMouseDown({
      time: now(),
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseUp({
      time: now(),
      currentView: NylasCalendar.WEEK_VIEW,
    })
    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass, this.picker);
    expect(ProposedTimeCalendarStore.proposals().length).toBe(1)
    expect(ProposedTimeCalendarStore.proposalsAsEvents().length).toBe(1)
    const proposals = $("proposal");
    const events = $("calendar-event");
    expect(events.length).toBe(1);
    expect(proposals.length).toBe(1);

    // It's not an availability block but a full blown proposal
    expect($("availability").length).toBe(0);
  });

  it("creates the time picker for the correct timespan", () => {
    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass, this.picker);
    const title = $("title");
    expect(ReactDOM.findDOMNode(title[0]).innerHTML).toBe("March 13 - March 19 2016");
  });

  it("creates a block of proposals on drag down", () => {
    this.picker._onCalendarMouseDown({
      time: now(),
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseMove({
      time: now().add(30, 'minutes'),
      mouseIsDown: true,
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseMove({
      time: now().add(60, 'minutes'),
      mouseIsDown: true,
      currentView: NylasCalendar.WEEK_VIEW,
    })
    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass, this.picker);

    // Ensure that we don't see any proposals
    expect(ProposedTimeCalendarStore.proposals().length).toBe(0)
    let proposalEls = $("proposal");
    expect(proposalEls.length).toBe(0);

    // But we DO see the drag block event
    expect(ProposedTimeCalendarStore.proposalsAsEvents().length).toBe(1)
    let events = $("calendar-event");
    expect($("availability").length).toBe(1);
    expect(events.length).toBe(1);

    this.picker._onCalendarMouseUp({
      time: now().add(90, 'minutes'),
      currentView: NylasCalendar.WEEK_VIEW,
    })

    // Now that we've moused up, this should convert them into proposals
    const proposals = ProposedTimeCalendarStore.proposals()
    expect(proposals.length).toBe(3)
    expect(ProposedTimeCalendarStore.proposalsAsEvents().length).toBe(3)
    proposalEls = $("proposal");
    events = $("calendar-event");
    expect(events.length).toBe(3);
    expect(proposalEls.length).toBe(3);

    const times = proposals.map((p) =>
      [p.start, p.end]
    );

    expect(times).toEqual([
      [now().unix(), now().add(30, 'minutes').unix()],
      [now().add(30, 'minutes').unix(),
        now().add(60, 'minutes').unix()],
      [now().add(60, 'minutes').unix(),
        now().add(90, 'minutes').unix()],
    ]);
  });

  it("creates a block of proposals on drag up", () => {
    this.picker._onCalendarMouseDown({
      time: now(),
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseMove({
      time: now().subtract(30, 'minutes'),
      mouseIsDown: true,
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseMove({
      time: now().subtract(60, 'minutes'),
      mouseIsDown: true,
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseUp({
      time: now().subtract(90, 'minutes'),
      currentView: NylasCalendar.WEEK_VIEW,
    })

    const proposals = ProposedTimeCalendarStore.proposals()
    const times = proposals.map((p) =>
      [p.start, p.end]
    );

    expect(times).toEqual([
      [now().subtract(90, 'minutes').unix(),
        now().subtract(60, 'minutes').unix()],
      [now().subtract(60, 'minutes').unix(),
        now().subtract(30, 'minutes').unix()],
      [now().subtract(30, 'minutes').unix(),
        now().unix()],
    ]);
  });

  it("removes proposals when clicked on", () => {
    // This created a proposal
    this.picker._onCalendarMouseDown({
      time: now(),
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseUp({
      time: now(),
      currentView: NylasCalendar.WEEK_VIEW,
    })

    // See the proposal is there
    expect(ProposedTimeCalendarStore.proposals().length).toBe(1)

    // Now let's find and click it.
    // This also tests to make sure it actually rendered
    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass, this.picker);
    const removeBtn = $("rm-time proposal");
    expect(removeBtn.length).toBe(1)
    ReactTestUtils.Simulate.mouseDown(ReactDOM.findDOMNode(removeBtn[0]))

    // Now see that it's gone!
    expect(ProposedTimeCalendarStore.proposals().length).toBe(0)
    // And gone from the DOM too.
    expect($("proposal").length).toBe(0);
    // And didn't turn into an availability block or something dumb
    expect($("availability").length).toBe(0);
  });

  it("can clear all of the proposals", () => {
    // This created a proposal
    this.picker._onCalendarMouseDown({
      time: now(),
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseUp({
      time: now(),
      currentView: NylasCalendar.WEEK_VIEW,
    })

    // See the proposal is there
    expect(ProposedTimeCalendarStore.proposals().length).toBe(1)

    // Find the clear button
    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass, this.picker);
    const clearBtns = $("clear-proposed-times");
    expect(clearBtns.length).toBe(1);

    // Click it
    ReactTestUtils.Simulate.click(ReactDOM.findDOMNode(clearBtns[0]))

    // Ensure no more proposals
    expect(ProposedTimeCalendarStore.proposals().length).toBe(0)
    // And nothing still rendered
    expect($("proposal").length).toBe(0);
    expect($("availability").length).toBe(0);
  });

  it("can change the duration", () => {
    // Find the duration picker.
    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass, this.picker);
    const pickerEls = $("duration-picker-select");
    expect(pickerEls.length).toBe(1);

    // Starts with default duration
    const d30Min = ProposedTimeCalendarStore.DURATIONS[0]
    expect(ProposedTimeCalendarStore._duration).toEqual(d30Min)

    const pickerEl = ReactDOM.findDOMNode(pickerEls[0]);
    pickerEl.value = "1.5|hours|1½ hr"
    ReactTestUtils.Simulate.change(pickerEl)

    const dHrHalf = ProposedTimeCalendarStore.DURATIONS[2]
    dHrHalf[0] = `${dHrHalf[0]}` // convert to string
    expect(ProposedTimeCalendarStore._duration).toEqual(dHrHalf)
  });

  it("creates a block of proposals with a longer duration", () => {
    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass, this.picker);

    // Create a single proposal with the default 30 min duration.
    this.picker._onCalendarMouseDown({
      time: now(),
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseUp({
      time: now(),
      currentView: NylasCalendar.WEEK_VIEW,
    })

    // It's 30 min long
    const proposals = ProposedTimeCalendarStore.proposals()
    const times = proposals.map((p) => [p.start, p.end]);
    expect(times).toEqual([
      [now().unix(),
        now().add(30, 'minutes').unix()],
    ]);

    // Change duration to 2.5 hours
    const pickerEl = ReactDOM.findDOMNode($("duration-picker-select")[0]);
    pickerEl.value = "2.5|hours|2½ hr"
    ReactTestUtils.Simulate.change(pickerEl)

    // Click a new event
    this.picker._onCalendarMouseDown({
      time: now().add(2, 'hours'),
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseUp({
      time: now().add(2, 'hours'),
      currentView: NylasCalendar.WEEK_VIEW,
    })

    // It should have added a 2.5 hour long event and left the original
    // event alone
    const p2 = ProposedTimeCalendarStore.proposals()
    const t2 = p2.map((p) => [p.start, p.end]);
    expect(t2).toEqual([
      [now().unix(),
        now().add(30, 'minutes').unix()],
      [now().add(2, 'hours').unix(),
        now().add(4.5, 'hours').unix()],
    ]);
  });

  it("overrides events so they don't overlap", () => {
    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass, this.picker);
    this.picker._onCalendarMouseDown({
      time: now(),
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseUp({
      time: now().add(1, 'hour'),
      currentView: NylasCalendar.WEEK_VIEW,
    })

    // Creates two proposals.
    const proposals = ProposedTimeCalendarStore.proposals()
    const times = proposals.map((p) => [p.start, p.end]);
    expect(times).toEqual([
      [now().unix(),
        now().add(30, 'minutes').unix()],
      [now().add(30, 'minutes').unix(),
        now().add(60, 'minutes').unix()],
    ]);

    // Change the duration to 2 hours
    const pickerEl = ReactDOM.findDOMNode($("duration-picker-select")[0]);
    pickerEl.value = "2|hours|2 hr"
    ReactTestUtils.Simulate.change(pickerEl)

    // Click and drag overlapping the first of the original events.
    this.picker._onCalendarMouseDown({
      time: now().subtract(1.5, 'hours'),
      currentView: NylasCalendar.WEEK_VIEW,
    })
    this.picker._onCalendarMouseUp({
      time: now().add(20, 'minutes'),
      currentView: NylasCalendar.WEEK_VIEW,
    })

    // See that there's only 1 new event with the correct time and it
    // exhchanged it with the old one.
    //
    // It left the non overlapping one alone.
    const p2 = ProposedTimeCalendarStore.proposals()
    const t2 = p2.map((p) => [p.start, p.end]);
    expect(t2).toEqual([
      [now().add(30, 'minutes').unix(),
        now().add(60, 'minutes').unix()],
      [now().subtract(1.5, 'hours').unix(),
        now().add(30, 'minutes').unix()],
    ]);
  });
});
