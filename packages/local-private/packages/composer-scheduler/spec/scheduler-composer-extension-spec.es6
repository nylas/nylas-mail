import {PLUGIN_ID} from '../lib/scheduler-constants'
import {
  prepareDraft,
  setupCalendars,
  cleanupDraft,
} from './composer-scheduler-spec-helper'
import NewEventHelper from '../lib/composer/new-event-helper'
import SchedulerComposerExtension from '../lib/composer/scheduler-composer-extension'

const now = window.testNowMoment;

xdescribe('SchedulerComposerExtension', function schedulerComposerExtension() {
  beforeEach(() => {
    this.session = null
    // Will eventually fill this.session
    prepareDraft.call(this);

    waitsFor(() => {
      return this.session._draft
    })

    // Note: Needs to be in a `runs` block so it happens after the async
    // activities of `prepareDraft`
    runs(() => {
      setupCalendars.call(this);
      spyOn(NewEventHelper, "now").andReturn(now())
      NewEventHelper.restoreOrCreateEvent(this.session)
    })
    waitsFor(() =>
      this.session.draft().metadataForPluginId(PLUGIN_ID)
    )
  });

  afterEach(() => {
    cleanupDraft()
  })

  // TODO: This moved to OverlaidComponents
  // describe("Inserting a new event", () => {
  //   beforeEach(() => {
  //     this.nextDraft = SchedulerComposerExtension.applyTransformsForSending({
  //       draft: this.session.draft(),
  //     });
  //   });
  //
  //   it("Inserts the proposted-time-list", () => {
  //     expect(this.nextDraft.body).toMatch(/new-event-preview/);
  //   });
  //
  //   it("Has the correct start and end times in the body", () => {
  //     const startStr = moment.unix(now().unix()).format("LT")
  //     const endStr = moment.unix(now().add(1, 'hour').unix()).format("LT")
  //
  //     const re = new RegExp(`Tuesday, March 15, 2016 <br\/>${startStr} – ${endStr}`)
  //
  //     // NOTE: These are supposed to render in local time. Make sure we
  //     // test for the local timezone of the test setup.
  //     expect(this.nextDraft.body).toMatch(re);
  //   });
  //
  //   it("Doesn't include proposed times", () => {
  //     expect(this.nextDraft.body).not.toMatch(/proposed-time-table/);
  //   });
  // });
  //
  // describe("When proposals are prsent", () => {
  //   it("inserts the proposals into the draft body", () => {
  //     const start = now().add(1, 'hour').unix();
  //     const end = now().add(2, 'hours').unix();
  //
  //     const startStr = moment.unix(start).format("LT")
  //     const endStr = moment.unix(end).format("LT")
  //
  //     const re = new RegExp(`${startStr} — ${endStr}`)
  //
  //     const draft = new Message({body: ''})
  //     draft.applyPluginMetadata(PLUGIN_ID, {
  //       pendingEvent: new Event(),
  //       proposals: [new Proposal({start, end})],
  //     })
  //
  //     const nextDraft = SchedulerComposerExtension.applyTransformsForSending({draft});
  //     expect(nextDraft.body).not.toMatch(/new-event-preview/);
  //     expect(nextDraft.body).toMatch(/proposed-time-table/);
  //     expect(nextDraft.body).toMatch(re);
  //   });
  // });

  // The backend will use whatever is stored in the `pendingEvent` field
  // to POST to the /events API endpoint. This means the data must be
  // a valid event. Verify that it meets Nylas API specs
  describe("When setting the event JSON to match server requirements", () => {
    beforeEach(() => {
      this.draft = this.session.draft();
      SchedulerComposerExtension.applyTransformsForSending({draft: this.draft});
      this.metadata = this.draft.metadataForPluginId(PLUGIN_ID);
      this.pendingEvent = this.metadata.pendingEvent
    });

    it("doesn't have a clientId", () => {
      expect(this.pendingEvent.client_id).not.toBeDefined();
      expect(this.pendingEvent.clientId).not.toBeDefined();
    });

    it("doesn't have an id", () => {
      expect(this.pendingEvent.id).not.toBeDefined();
      expect(this.pendingEvent.serverId).not.toBeDefined();
      expect(this.pendingEvent.server_id).not.toBeDefined();
    });

    it("has the correct `when` block", () => {
      expect(this.pendingEvent.when).toEqual({
        start_time: now().unix(),
        end_time: now().add(1, 'hour').unix(),
      })
      expect(this.pendingEvent.when.object).not.toBeDefined();
    });

    it("doesn't have _start or _end blocks", () => {
      expect(this.pendingEvent._start).not.toBeDefined();
      expect(this.pendingEvent._end).not.toBeDefined();
    });

    it("has the correct participants", () => {
      const from = this.draft.from[0]
      expect(this.pendingEvent.participants.length).toBe(1);
      expect(this.pendingEvent.participants[0].name).toBe(from.name);
      expect(this.pendingEvent.participants[0].email).toBe(from.email);
      expect(this.pendingEvent.participants[0].status).toBe("noreply");
    });

    // NOTE: The backend requires a `uid` key on the metadata in order to
    // properly look up the pending event. This must be present in order
    // for the service to work.
    it("IMPORTANT: Puts the draft client ID on the `uid` key", () => {
      const id = this.draft.clientId
      expect(this.metadata.uid).toBe(id);
    })

    it("only has appropriate keys", () => {
      expect(Object.keys(this.pendingEvent)).toEqual([
        "calendar_id",
        "title",
        "participants",
        "when",
      ])
    });
  });
});
