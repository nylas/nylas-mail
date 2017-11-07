import React from 'react';
import ReactTestUtils from 'react-dom/test-utils';
import {
  Thread,
  Actions,
  Contact,
  Message,
  DatabaseStore,
  FocusedPerspectiveStore,
} from 'mailspring-exports';
import ActivityList from '../lib/activity-list';
import ActivityEventStore from '../lib/activity-event-store';
import TestDataSource from '../lib/test-data-source';

const OPEN_TRACKING_ID = 'open-tracking-id';
const LINK_TRACKING_ID = 'link-tracking-id';

const messages = [
  new Message({
    id: 'a',
    accountId: '0000000000000000000000000',
    bcc: [],
    cc: [],
    snippet: 'Testing.',
    subject: 'Open me!',
    threadId: '0000000000000000000000000',
    to: [
      new Contact({
        name: 'Jackie Luo',
        email: 'jackie@nylas.com',
      }),
    ],
  }),
  new Message({
    id: 'b',
    accountId: '0000000000000000000000000',
    bcc: [
      new Contact({
        name: 'Ben Gotow',
        email: 'ben@nylas.com',
      }),
    ],
    cc: [],
    snippet: 'Hey! I am in town for the week...',
    subject: 'Coffee?',
    threadId: '0000000000000000000000000',
    to: [
      new Contact({
        name: 'Jackie Luo',
        email: 'jackie@nylas.com',
      }),
    ],
  }),
  new Message({
    id: 'c',
    accountId: '0000000000000000000000000',
    bcc: [],
    cc: [
      new Contact({
        name: 'Evan Morikawa',
        email: 'evan@nylas.com',
      }),
    ],
    snippet: "Here's the latest deals!",
    subject: 'Newsletter',
    threadId: '0000000000000000000000000',
    to: [
      new Contact({
        name: 'Juan Tejada',
        email: 'juan@nylas.com',
      }),
    ],
  }),
];

let pluginValue = {
  open_count: 1,
  open_data: [
    {
      timestamp: 1461361759.351055,
    },
  ],
};
messages[0].directlyAttachMetadata(OPEN_TRACKING_ID, pluginValue);
pluginValue = {
  links: [
    {
      click_count: 1,
      click_data: [
        {
          timestamp: 1461349232.495837,
        },
      ],
    },
  ],
  tracked: true,
};
messages[0].directlyAttachMetadata(LINK_TRACKING_ID, pluginValue);
pluginValue = {
  open_count: 1,
  open_data: [
    {
      timestamp: 1461361763.28372,
    },
  ],
};
messages[1].directlyAttachMetadata(OPEN_TRACKING_ID, pluginValue);
pluginValue = {
  links: [],
  tracked: false,
};
messages[1].directlyAttachMetadata(LINK_TRACKING_ID, pluginValue);
pluginValue = {
  open_count: 0,
  open_data: [],
};
messages[2].directlyAttachMetadata(OPEN_TRACKING_ID, pluginValue);
pluginValue = {
  links: [
    {
      click_count: 0,
      click_data: [],
    },
  ],
  tracked: true,
};
messages[2].directlyAttachMetadata(LINK_TRACKING_ID, pluginValue);

describe('ActivityList', function activityList() {
  beforeEach(() => {
    this.testSource = new TestDataSource();
    spyOn(AppEnv.packages, 'pluginIdFor').andCallFake(pluginName => {
      if (pluginName === 'open-tracking') {
        return OPEN_TRACKING_ID;
      }
      if (pluginName === 'link-tracking') {
        return LINK_TRACKING_ID;
      }
      return null;
    });
    spyOn(ActivityEventStore, '_dataSource').andReturn(this.testSource);
    spyOn(FocusedPerspectiveStore, 'sidebarAccountIds').andReturn(['0000000000000000000000000']);
    spyOn(DatabaseStore, 'run').andCallFake(query => {
      if (query._klass === Thread) {
        const thread = new Thread({
          id: '0000000000000000000000000',
          accountId: TEST_ACCOUNT_ID,
        });
        return Promise.resolve(thread);
      }
      return null;
    });
    spyOn(ActivityEventStore, 'focusThread').andCallThrough();
    spyOn(AppEnv, 'displayWindow');
    spyOn(Actions, 'closePopover');
    spyOn(Actions, 'setFocus');
    spyOn(Actions, 'ensureCategoryIsFocused');
    ActivityEventStore.activate();
    this.component = ReactTestUtils.renderIntoDocument(<ActivityList />);
  });

  describe('when no actions are found', () => {
    it('should show empty state', () => {
      const items = ReactTestUtils.scryRenderedDOMComponentsWithClass(
        this.component,
        'activity-list-item'
      );
      expect(items.length).toBe(0);
    });
  });

  describe('when actions are found', () => {
    it('should show activity list items', () => {
      this.testSource.manuallyTrigger(messages);
      waitsFor(() => {
        const items = ReactTestUtils.scryRenderedDOMComponentsWithClass(
          this.component,
          'activity-list-item'
        );
        return items.length > 0;
      });
      runs(() => {
        expect(
          ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'activity-list-item')
            .length
        ).toBe(3);
      });
    });

    it('should show the correct items', () => {
      this.testSource.manuallyTrigger(messages);
      waitsFor(() => {
        const items = ReactTestUtils.scryRenderedDOMComponentsWithClass(
          this.component,
          'activity-list-item'
        );
        return items.length > 0;
      });
      runs(() => {
        expect(
          ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'activity-list-item')[0]
            .textContent
        ).toBe('Someone opened:Apr 22 2016Coffee?');
        expect(
          ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'activity-list-item')[1]
            .textContent
        ).toBe('Jackie Luo opened:Apr 22 2016Open me!');
        expect(
          ReactTestUtils.scryRenderedDOMComponentsWithClass(this.component, 'activity-list-item')[2]
            .textContent
        ).toBe('Jackie Luo clicked:Apr 22 2016(No Subject)');
      });
    });

    xit('should focus the thread', () => {
      runs(() => {
        return this.testSource.manuallyTrigger(messages);
      });
      waitsFor(() => {
        const items = ReactTestUtils.scryRenderedDOMComponentsWithClass(
          this.component,
          'activity-list-item'
        );
        return items.length > 0;
      });
      runs(() => {
        const item = ReactTestUtils.scryRenderedDOMComponentsWithClass(
          this.component,
          'activity-list-item'
        )[0];
        ReactTestUtils.Simulate.click(item);
      });
      waitsFor(() => {
        return ActivityEventStore.focusThread.calls.length > 0;
      });
      runs(() => {
        expect(AppEnv.displayWindow.calls.length).toBe(1);
        expect(Actions.closePopover.calls.length).toBe(1);
        expect(Actions.setFocus.calls.length).toBe(1);
        expect(Actions.ensureCategoryIsFocused.calls.length).toBe(1);
      });
    });
  });
});
