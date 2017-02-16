import _ from 'underscore'
import React from 'react'
import ReactDOM from 'react-dom'
import ReactTestUtils from 'react-addons-test-utils';

import {
  Event,
  DatabaseStore,
} from 'nylas-exports'

import {PLUGIN_ID} from '../lib/scheduler-constants'
import NewEventCard from '../lib/composer/new-event-card'
import NewEventCardContainer from '../lib/composer/new-event-card-container'

import Proposal from '../lib/proposal'
import SchedulerActions from '../lib/scheduler-actions'

import {
  DRAFT_CLIENT_ID,
  prepareDraft,
  testCalendars,
  cleanupDraft,
} from './composer-scheduler-spec-helper'

const now = window.testNowMoment

xdescribe('NewEventCard', function newEventCard() {
  beforeEach(() => {
    this.session = null
    prepareDraft.call(this)

    waitsFor(() => {
      return this.session._draft
    })

    runs(() => {
      this.eventCardContainer = ReactTestUtils.renderIntoDocument(
        <NewEventCardContainer draft={this.session.draft()} session={this.session} />
      );
    })
  });

  afterEach(() => {
    cleanupDraft()
  })

  const setNewTestEvent = () => {
    if (!this.session) {
      throw new Error("Setup test session first")
    }
    this.session.changes.addPluginMetadata(PLUGIN_ID, {
      uid: DRAFT_CLIENT_ID,
      pendingEvent: new Event({
        calendarId: "TEST_CALENDAR_ID",
        title: "",
        start: now().unix(),
        end: now().add(1, 'hour').unix(),
      }).toJSON(),
    });

    this.eventCardContainer = ReactTestUtils.renderIntoDocument(
      <NewEventCardContainer draft={this.session.draft()} session={this.session} />
    );
  }

  const getPendingEvent = () =>
    this.session.draft().metadataForPluginId(PLUGIN_ID).pendingEvent

  it("creates a new event card", () => {
    const el = ReactTestUtils.findRenderedComponentWithType(this.eventCardContainer,
        NewEventCardContainer);
    expect(el instanceof NewEventCardContainer).toBe(true)
  });

  it("doesn't render if there's no event on metadata", () => {
    expect(this.eventCardContainer.refs.newEventCard).not.toBeDefined();
  });

  it("renders the event card when an event is created", () => {
    setNewTestEvent()
    expect(this.eventCardContainer.refs.newEventCard).toBeDefined();
    expect(this.eventCardContainer.refs.newEventCard instanceof NewEventCard).toBe(true);
  });

  it("loads the calendars for email", () => {
    setNewTestEvent()
    waitsFor(() =>
      this.eventCardContainer.refs.newEventCard.state.calendars.length > 0
    )
    runs(() => {
      const newCardRef = this.eventCardContainer.refs.newEventCard;
      expect(newCardRef.state.calendars).toEqual(testCalendars());
    });
  });

  it("removes the event and clears metadata", () => {
    setNewTestEvent()

    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass,
      this.eventCardContainer);
    const rmBtn = ReactDOM.findDOMNode($("remove-button")[0]);

    // The event is there before clicking remove
    expect(this.eventCardContainer.refs.newEventCard).toBeDefined()
    expect(this.session.draft().metadataForPluginId(PLUGIN_ID).pendingEvent).toBeDefined()

    ReactTestUtils.Simulate.click(rmBtn);

    // The event has been removed from metadata
    expect(this.session.draft().metadataForPluginId(PLUGIN_ID).pendingEvent).not.toBeDefined()
  });

  it("properly updates the event", () => {
    setNewTestEvent()
    const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass,
      this.eventCardContainer);
    const title = ReactDOM.findDOMNode($("event-title")[0]);

    // The event has the old title
    expect(getPendingEvent().title).toBe("")

    title.value = "Test"
    ReactTestUtils.Simulate.change(title);

    // The event has the new title
    expect(getPendingEvent().title).toBe("Test")
  });

  it("updates the day", () => {
    setNewTestEvent()
    const eventCard = this.eventCardContainer.refs.newEventCard;

    // The event has the default day
    const nowUnix = now().unix()
    expect(getPendingEvent()._start).toBe(nowUnix)

    // The event has the new day
    const newDay = now().add(2, 'days');
    eventCard._onChangeDay(newDay.valueOf());

    expect(getPendingEvent()._start).toBe(newDay.unix())
  });

  it("updates the time properly", () => {
    setNewTestEvent()
    const eventCard = this.eventCardContainer.refs.newEventCard;

    const oldEnd = now().add(1, 'hour').unix()
    expect(getPendingEvent()._start).toBe(now().unix())
    expect(getPendingEvent()._end).toBe(oldEnd)

    const newStart = now().subtract(1, 'hour');
    eventCard._onChangeStartTime(newStart.valueOf());

    expect(getPendingEvent()._start).toBe(newStart.unix())
    expect(getPendingEvent()._end).toBe(oldEnd)
  });

  it("adjusts the times to prevent invalid times", () => {
    setNewTestEvent()
    const eventCard = this.eventCardContainer.refs.newEventCard;

    const start0 = now();
    const end0 = now().add(1, 'hour');

    const start1 = now().add(2, 'hours');
    const expectedEnd1 = now().add(3, 'hours');

    const expectedStart2 = now().subtract(3, 'hours');
    const end2 = now().subtract(2, 'hours');

    // The event has the start times
    expect(getPendingEvent()._start).toBe(start0.unix())
    expect(getPendingEvent()._end).toBe(end0.unix())

    eventCard._onChangeStartTime(start1.valueOf());

    // The event the new start time and also moved the end to match
    expect(getPendingEvent()._start).toBe(start1.unix())
    expect(getPendingEvent()._end).toBe(expectedEnd1.unix())

    eventCard._onChangeEndTime(end2.valueOf());

    // The event the new end time and also moved the start to match
    expect(getPendingEvent()._start).toBe(expectedStart2.unix())
    expect(getPendingEvent()._end).toBe(end2.unix())
  });

  it("switches calendars when the from account changes", () => {
    // TODO
  });

  describe("Inserting proposed times", () => {
    beforeEach(() => {
      const draft = this.session.draft()
      spyOn(DatabaseStore, "find").andReturn(Promise.resolve(draft));
      const start = now().add(1, 'hour').unix();
      const end = now().add(2, 'hours').unix();
      this.proposals = [new Proposal({start, end})]

      runs(() => {
        SchedulerActions.confirmChoices({
          proposals: this.proposals,
          draftClientId: DRAFT_CLIENT_ID,
        });
      })
      waitsFor(() => {
        const metadata = this.session.draft().metadataForPluginId(PLUGIN_ID);
        return (metadata.proposals || []).length > 0;
      })
    });

    it("inserts proposed times on metadata", () => {
      const metadata = this.session.draft().metadataForPluginId(PLUGIN_ID);
      expect(JSON.stringify(metadata.proposals)).toEqual(JSON.stringify(this.proposals));
    });
  });
});
