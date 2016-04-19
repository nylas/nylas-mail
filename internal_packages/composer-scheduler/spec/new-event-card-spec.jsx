import _ from 'underscore'
import React from 'react'
import ReactDOM from 'react-dom'
import {PLUGIN_ID} from '../lib/scheduler-constants'
import NewEventCard from '../lib/composer/new-event-card'
import ReactTestUtils from 'react-addons-test-utils';
import NewEventCardContainer from '../lib/composer/new-event-card-container'

import {
  Calendar,
  Event,
  DatabaseStore,
} from 'nylas-exports'

import {
  DRAFT_CLIENT_ID,
  prepareDraft,
  cleanupDraft,
} from './composer-scheduler-spec-helper'

const now = window.testNowMoment

describe("NewEventCard", () => {
  beforeEach(() => {
    this.session = null
    // Will eventually fill this.session
    prepareDraft.call(this)

    runs(() => {
      this.eventCardContainer = ReactTestUtils.renderIntoDocument(
        <NewEventCardContainer draftClientId={DRAFT_CLIENT_ID} />
      );
    })

    waitsFor(() => this.eventCardContainer._session)
  });

  afterEach(() => {
    cleanupDraft()
  })

  const testCalendars = () => [new Calendar({
    clientId: "client-1",
    servierId: "server-1",
    name: "Test Calendar",
  })]

  const stubCalendars = (calendars = []) => {
    jasmine.unspy(DatabaseStore, "run")
    spyOn(DatabaseStore, "run").andCallFake((query) => {
      if (query.objectClass() === Calendar.name) {
        return Promise.resolve(calendars)
      }
      return Promise.resolve()
    })
  }

  const setNewTestEvent = (callback) => {
    runs(() => {
      if (!this.session) {
        throw new Error("Setup test session first")
      }
      const metadata = {}
      metadata.uid = DRAFT_CLIENT_ID;
      metadata.pendingEvent = new Event({
        calendarId: "TEST_CALENDAR_ID",
        title: "",
        start: now().unix(),
        end: now().add(1, 'hour').unix(),
      }).toJSON();
      this.session.changes.addPluginMetadata(PLUGIN_ID, metadata);
    })

    waitsFor(() => this.eventCardContainer.state.event);

    runs(callback)
  }

  it("creates a new event card", () => {
    const el = ReactTestUtils.findRenderedComponentWithType(this.eventCardContainer,
        NewEventCardContainer);
    expect(el instanceof NewEventCardContainer).toBe(true)
  });

  it("doesn't render if there's no event on metadata", () => {
    expect(this.eventCardContainer.refs.newEventCard).not.toBeDefined();
  });

  it("renders the event card when an event is created", () => {
    stubCalendars()
    setNewTestEvent(() => {
      expect(this.eventCardContainer.refs.newEventCard).toBeDefined();
      expect(this.eventCardContainer.refs.newEventCard instanceof NewEventCard).toBe(true);
    })
  });

  it("loads the calendars for email", () => {
    stubCalendars(testCalendars())
    setNewTestEvent(() => { })
    waitsFor(() =>
      this.eventCardContainer.refs.newEventCard.state.calendars.length > 0
    )
    runs(() => {
      const newEventCard = this.eventCardContainer.refs.newEventCard;
      expect(newEventCard.state.calendars).toEqual(testCalendars());
    });
  });

  it("removes the event and clears metadata", () => {
    stubCalendars(testCalendars())
    setNewTestEvent(() => {
      const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass,
        this.eventCardContainer);
      const rmBtn = ReactDOM.findDOMNode($("remove-button")[0]);

      // The event is there before clicking remove
      expect(this.eventCardContainer.state.event).toBeDefined()
      expect(this.eventCardContainer.refs.newEventCard).toBeDefined()
      expect(this.session.draft().metadataForPluginId(PLUGIN_ID).pendingEvent).toBeDefined()

      ReactTestUtils.Simulate.click(rmBtn);

      // The event has been removed from metadata and state
      expect(this.eventCardContainer.state.event).toBe(null)
      expect(this.eventCardContainer.refs.newEventCard).not.toBeDefined()
      expect(this.session.draft().metadataForPluginId(PLUGIN_ID).pendingEvent).not.toBeDefined()
    })
  });

  const getPendingEvent = () =>
    this.session.draft().metadataForPluginId(PLUGIN_ID).pendingEvent

  it("properly updates the event", () => {
    stubCalendars(testCalendars())
    setNewTestEvent(() => {
      const $ = _.partial(ReactTestUtils.scryRenderedDOMComponentsWithClass,
        this.eventCardContainer);
      const title = ReactDOM.findDOMNode($("event-title")[0]);

      // The event has the old title
      expect(this.eventCardContainer.state.event.title).toBe("")
      expect(getPendingEvent().title).toBe("")

      title.value = "Test"
      ReactTestUtils.Simulate.change(title);

      // The event has the new title
      expect(this.eventCardContainer.state.event.title).toBe("Test")
      expect(getPendingEvent().title).toBe("Test")
    })
  });

  it("updates the day", () => {
    stubCalendars(testCalendars())
    setNewTestEvent(() => {
      const eventCard = this.eventCardContainer.refs.newEventCard;

      // The event has the default day
      const nowUnix = now().unix()
      expect(this.eventCardContainer.state.event.start).toBe(nowUnix)
      expect(getPendingEvent()._start).toBe(nowUnix)

      // The event has the new day
      const newDay = now().add(2, 'days');
      eventCard._onChangeDay(newDay.valueOf());

      expect(this.eventCardContainer.state.event.start).toBe(newDay.unix())
      expect(getPendingEvent()._start).toBe(newDay.unix())
    })
  });

  it("updates the time properly", () => {
    stubCalendars(testCalendars())
    setNewTestEvent(() => {
      const eventCard = this.eventCardContainer.refs.newEventCard;

      const oldEnd = now().add(1, 'hour').unix()
      expect(this.eventCardContainer.state.event.start).toBe(now().unix())
      expect(getPendingEvent()._start).toBe(now().unix())
      expect(getPendingEvent()._end).toBe(oldEnd)

      const newStart = now().subtract(1, 'hour');
      eventCard._onChangeStartTime(newStart.valueOf());

      expect(this.eventCardContainer.state.event.start).toBe(newStart.unix())
      expect(getPendingEvent()._start).toBe(newStart.unix())
      expect(this.eventCardContainer.state.event.end).toBe(oldEnd)
      expect(getPendingEvent()._end).toBe(oldEnd)
    })
  });

  it("adjusts the times to prevent invalid times", () => {
    stubCalendars(testCalendars())
    setNewTestEvent(() => {
      const eventCard = this.eventCardContainer.refs.newEventCard;
      let event = this.eventCardContainer.state.event;

      const start0 = now();
      const end0 = now().add(1, 'hour');

      const start1 = now().add(2, 'hours');
      const expectedEnd1 = now().add(3, 'hours');

      const expectedStart2 = now().subtract(3, 'hours');
      const end2 = now().subtract(2, 'hours');

      // The event has the start times
      expect(event.start).toBe(start0.unix())
      expect(event.end).toBe(end0.unix())
      expect(getPendingEvent()._start).toBe(start0.unix())
      expect(getPendingEvent()._end).toBe(end0.unix())

      eventCard._onChangeStartTime(start1.valueOf());

      // The event the new start time and also moved the end to match
      event = this.eventCardContainer.state.event;
      expect(event.start).toBe(start1.unix())
      expect(event.end).toBe(expectedEnd1.unix())
      expect(getPendingEvent()._start).toBe(start1.unix())
      expect(getPendingEvent()._end).toBe(expectedEnd1.unix())

      eventCard._onChangeEndTime(end2.valueOf());

      // The event the new end time and also moved the start to match
      event = this.eventCardContainer.state.event;
      expect(event.start).toBe(expectedStart2.unix())
      expect(event.end).toBe(end2.unix())
      expect(getPendingEvent()._start).toBe(expectedStart2.unix())
      expect(getPendingEvent()._end).toBe(end2.unix())
    })
  });
});
