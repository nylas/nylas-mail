import React from 'react'
import ReactTestUtils from 'react-addons-test-utils'
import {NylasCalendar} from 'nylas-component-kit'

import { now } from './test-utils'
import TestDataSource from './test-data-source'
import CalendarToggles from '../../../src/components/nylas-calendar/calendar-toggles'

describe("Nylas Calendar Toggles", function calendarPickerSpec() {
  beforeEach(() => {
    this.dataSource = new TestDataSource();
    this.calendar = ReactTestUtils.renderIntoDocument(
      <NylasCalendar
        currentMoment={now()}
        onCalendarMouseDown={this.onCalendarMouseDown}
        dataSource={this.dataSource}
      />
    );
    this.toggles = ReactTestUtils.findRenderedComponentWithType(this.calendar, CalendarToggles);
  });
});
