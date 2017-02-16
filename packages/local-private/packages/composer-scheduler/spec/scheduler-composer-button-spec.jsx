import React from 'react'
import ReactDOM from 'react-dom'
import ReactTestUtils from 'react-addons-test-utils'

import {APIError, Actions, NylasAPIHelpers} from 'nylas-exports'
import {PLUGIN_ID, PLUGIN_NAME} from '../lib/scheduler-constants'

import SchedulerComposerButton from '../lib/composer/scheduler-composer-button'

import NewEventHelper from '../lib/composer/new-event-helper'

import SchedulerActions from '../lib/scheduler-actions'

import {
  prepareDraft,
  cleanupDraft,
  setupCalendars,
} from './composer-scheduler-spec-helper'

const now = window.testNowMoment;

xdescribe('SchedulerComposerButton', function schedulerComposerButton() {
  beforeEach(() => {
    this.session = null
    spyOn(Actions, "openPopover").andCallThrough();
    spyOn(Actions, "closePopover").andCallThrough();
    spyOn(NylasEnv, "reportError")
    spyOn(NylasEnv, "showErrorDialog")
    spyOn(NewEventHelper, "now").andReturn(now())

    prepareDraft.call(this)

    waitsFor(() => {
      return this.session._draft
    })

    runs(() => {
      this.schedulerBtn = ReactTestUtils.renderIntoDocument(
        <SchedulerComposerButton draft={this.session.draft()} session={this.session} />
      );
    })
  });

  afterEach(() => {
    cleanupDraft()
  })

  const spyAuthSuccess = () => {
    spyOn(NylasAPIHelpers, "authPlugin").andCallFake((pluginId, pluginName, accountId) => {
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
    spyOn(NylasAPIHelpers, "authPlugin").andReturn(Promise.reject(err));
    testForError(err);
    runs(() => {
      expect(NylasEnv.reportError).toHaveBeenCalledWith(err);
    })
  });

  it("errors on unexpected errors and reports", () => {
    const err = new Error("OH NO");
    spyOn(NylasAPIHelpers, "authPlugin").andReturn(Promise.reject(err));
    testForError(err);
    runs(() => {
      expect(NylasEnv.reportError).toHaveBeenCalledWith(err);
    })
  });

  it("errors on offline, but doesn't report", () => {
    const err = new APIError({statusCode: 0});
    spyOn(NylasAPIHelpers, "authPlugin").andReturn(Promise.reject(err));
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
      expect(NylasAPIHelpers.authPlugin).toHaveBeenCalled()
      expect(NylasAPIHelpers.authPlugin.calls.length).toBe(1)
    });

    it("fires the scheduler action to insert the anchor into the contenteditable", () => {
      setupCalendars();
      spyOn(SchedulerActions, "insertNewEventCard")
      runs(() => {
        ReactTestUtils.Simulate.mouseDown(this.meetingRequestBtn);
      })
      waitsFor(() =>
        SchedulerActions.insertNewEventCard.calls.length > 0
      );
      runs(() => {
        expect(Actions.closePopover).toHaveBeenCalled();
        expect(SchedulerActions.insertNewEventCard.calls.length).toBe(1)
        expect(NylasEnv.showErrorDialog).not.toHaveBeenCalled()
      })
    });
  });
});
