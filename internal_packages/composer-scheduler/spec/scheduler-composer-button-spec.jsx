import React from 'react'
import ReactDOM from 'react-dom'
import ReactTestUtils from 'react-addons-test-utils'

import {DatabaseStore, Calendar, APIError, Actions, NylasAPI} from 'nylas-exports'
import {PLUGIN_ID, PLUGIN_NAME} from '../lib/scheduler-constants'

import SchedulerComposerButton from '../lib/composer/scheduler-composer-button'

import NewEventHelper from '../lib/composer/new-event-helper'

import {
  prepareDraft,
  cleanupDraft,
  setupCalendars,
  DRAFT_CLIENT_ID,
} from './composer-scheduler-spec-helper'

const now = window.testNowMoment;

describe("SchedulerComposerButton", () => {
  beforeEach(() => {
    this.session = null
    spyOn(Actions, "openPopover").andCallThrough();
    spyOn(Actions, "closePopover").andCallThrough();
    spyOn(NylasEnv, "reportError")
    spyOn(NylasEnv, "showErrorDialog")
    spyOn(NewEventHelper, "now").andReturn(now())

    prepareDraft.call(this)
    this.schedulerBtn = ReactTestUtils.renderIntoDocument(
      <SchedulerComposerButton draft={this.session.draft()} session={this.session} />
    );
  });

  afterEach(() => {
    cleanupDraft()
  })

  const spyAuthSuccess = () => {
    spyOn(NylasAPI, "authPlugin").andCallFake((pluginId, pluginName, accountId) => {
      expect(pluginId).toBe(PLUGIN_ID);
      expect(pluginName).toBe(PLUGIN_NAME);
      expect(accountId).toBe(window.TEST_ACCOUNT_ID);
      return Promise.resolve();
    })
  }

  it("loads the draft and renders the button", () => {
    const el = ReactTestUtils.findRenderedComponentWithType(this.schedulerBtn,
        SchedulerComposerButton);
    expect(el instanceof SchedulerComposerButton).toBe(true)
  });

  const testForError = () => {
    runs(() => {
      ReactTestUtils.Simulate.click(ReactDOM.findDOMNode(this.schedulerBtn));
    })
    waitsFor(() =>
      NylasEnv.showErrorDialog.calls.length > 0
    );
    runs(() => {
      const picker = document.querySelector(".scheduler-picker")
      expect(Actions.openPopover).toHaveBeenCalled();
      expect(Actions.closePopover).toHaveBeenCalled();
      expect(picker).toBe(null);
    })
  }

  it("errors on 400 error and reports", () => {
    const err = new APIError({statusCode: 400});
    spyOn(NylasAPI, "authPlugin").andReturn(Promise.reject(err));
    testForError(err);
    runs(() => {
      expect(NylasEnv.reportError).toHaveBeenCalledWith(err);
    })
  });

  it("errors on unexpected errors and reports", () => {
    const err = new Error("OH NO");
    spyOn(NylasAPI, "authPlugin").andReturn(Promise.reject(err));
    testForError(err);
    runs(() => {
      expect(NylasEnv.reportError).toHaveBeenCalledWith(err);
    })
  });

  it("errors on offline, but doesn't report", () => {
    const err = new APIError({statusCode: 0});
    spyOn(NylasAPI, "authPlugin").andReturn(Promise.reject(err));
    testForError(err);
    runs(() => {
      expect(NylasEnv.reportError).not.toHaveBeenCalled();
    })
  });

  describe("auth success", () => {
    beforeEach(() => {
      spyAuthSuccess();
      ReactTestUtils.Simulate.click(ReactDOM.findDOMNode(this.schedulerBtn));
      const items = document.querySelectorAll(".scheduler-picker .item");
      this.meetingRequestBtn = items[0];
      this.proposalBtn = items[1];
    });

    it("renders the popover on click", () => {
      // The popover renders outside the scope of the component.
      const picker = document.querySelector(".scheduler-picker")
      expect(Actions.openPopover).toHaveBeenCalled();
      expect(picker).toBeDefined();
    });

    it("auths the plugin on click", () => {
      expect(NylasAPI.authPlugin).toHaveBeenCalled()
      expect(NylasAPI.authPlugin.calls.length).toBe(1)
    });

    it("creates a new event on the metadata", () => {
      setupCalendars();
      spyOn(this.session.changes, "addPluginMetadata").andCallThrough()
      runs(() => {
        ReactTestUtils.Simulate.mouseDown(this.meetingRequestBtn);
      })
      waitsFor(() =>
        this.session.changes.addPluginMetadata.calls.length > 0
      );
      runs(() => {
        expect(Actions.closePopover).toHaveBeenCalled();
        const metadata = this.session.draft().metadataForPluginId(PLUGIN_ID);
        expect(metadata.pendingEvent._start).toBe(now().unix())
        expect(metadata.pendingEvent._end).toBe(now().add(1, 'hour').unix())
        expect(NylasEnv.showErrorDialog).not.toHaveBeenCalled()
      })
    });

    // NOTE: The backend requires a `uid` key on the metadata in order to
    // properly look up the pending event. This must be present in order
    // for the service to work.
    it("IMPORTANT: puts the draft client ID on the `uid` key", () => {
      setupCalendars();
      spyOn(this.session.changes, "addPluginMetadata").andCallThrough()
      runs(() => {
        ReactTestUtils.Simulate.mouseDown(this.meetingRequestBtn);
      })
      waitsFor(() =>
        this.session.changes.addPluginMetadata.calls.length > 0
      );
      runs(() => {
        const metadata = this.session.draft().metadataForPluginId(PLUGIN_ID);
        expect(metadata.uid).toBe(DRAFT_CLIENT_ID)
      })
    });

    it("throws an error if there aren't any calendars", () => {
      // Only a read-only calendar
      spyOn(DatabaseStore, "findAll").andCallFake((klass, {accountId}) => {
        const cals = [
          new Calendar({accountId, readOnly: true, name: 'b'}),
        ]
        return Promise.resolve(cals);
      })

      runs(() => {
        ReactTestUtils.Simulate.mouseDown(this.meetingRequestBtn);
      })
      waitsFor(() =>
        NylasEnv.showErrorDialog.calls.length > 0
      );
      runs(() => {
        expect(Actions.closePopover).toHaveBeenCalled();
        const metadata = this.session.draft().metadataForPluginId(PLUGIN_ID);
        expect(metadata).toBe(null);
        expect(NylasEnv.showErrorDialog.calls.length).toBe(1)
      })
    });
  });
});
