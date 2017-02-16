import moment from 'moment-timezone'
import {Event} from 'nylas-exports'
import {TZ, TEST_CALENDAR} from '../test-utils'

// All day
// All day overlap
//
// Simple single event
// Event that spans a day
// Overlapping events

let gen = 0

const genEvent = ({start, end, object = "timespan"}) => {
  gen += 1;

  let when = {}
  if (object === "timespan") {
    when = {
      object: "timespan",
      end_time: moment.tz(end, TZ).unix(),
      start_time: moment.tz(start, TZ).unix(),
    }
  }
  if (object === "datespan") {
    when = {
      object: "datespan",
      end_date: end,
      start_date: start,
    }
  }

  return new Event().fromJSON({
    id: `server-${gen}`,
    calendar_id: TEST_CALENDAR,
    account_id: window.TEST_ACCOUNT_ID,
    description: `description ${gen}`,
    location: `location ${gen}`,
    owner: `${window._TEST_ACCOUNT_NAME} <${window.TEST_ACCOUNT_EMAIL}>`,
    participants: [{
      email: window.TEST_ACCOUNT_EMAIL,
      name: window.TEST_ACCOUNT_NAME,
      status: "yes",
    }],
    read_only: "false",
    title: `Title ${gen}`,
    busy: true,
    when,
    status: "confirmed",
  })
}

// NOTE:
// DST Started 2016-03-13 01:59 and immediately jumps to 03:00.
// DST Ended 2016-11-06 01:59 and immediately jumps to 01:00 again!
//
// See: http://momentjs.com/timezone/docs/#/using-timezones/parsing-ambiguous-inputs/

// All times are in "America/Los_Angeles"
export const numAllDayEvents = 6
export const numStandardEvents = 9
export const numByDay = {
  1457769600: 2,
  1457856000: 7,
}
export const eventOverlapForSunday = {
  "server-2": {
    concurrentEvents: 2,
    order: 1,
  },
  "server-3": {
    concurrentEvents: 2,
    order: 2,
  },
  "server-6": {
    concurrentEvents: 1,
    order: 1,
  },
  "server-7": {
    concurrentEvents: 1,
    order: 1,
  },
  "server-8": {
    concurrentEvents: 2,
    order: 1,
  },
  "server-9": {
    concurrentEvents: 2,
    order: 2,
  },
  "server-10": {
    concurrentEvents: 2,
    order: 1,
  },
}
export const events = [
  // Single event
  genEvent({start: "2016-03-12 12:00", end: "2016-03-12 13:00"}),

  // DST start spanning event. 6 hours when it should be 7!
  genEvent({start: "2016-03-12 23:00", end: "2016-03-13 06:00"}),

  // DST start invalid event. Does not exist!
  genEvent({start: "2016-03-13 02:15", end: "2016-03-13 02:45"}),

  // DST end spanning event. 8 hours when it shoudl be 7!
  genEvent({start: "2016-11-05 23:00", end: "2016-11-06 06:00"}),

  // DST end ambiguous event. This timespan happens twice!
  genEvent({start: "2016-11-06 01:15", end: "2016-11-06 01:45"}),

  // Adjacent events
  genEvent({start: "2016-03-13 12:00", end: "2016-03-13 13:00"}),
  genEvent({start: "2016-03-13 13:00", end: "2016-03-13 14:00"}),

  // Overlapping events
  genEvent({start: "2016-03-13 14:30", end: "2016-03-13 15:30"}),
  genEvent({start: "2016-03-13 15:00", end: "2016-03-13 16:00"}),
  genEvent({start: "2016-03-13 15:30", end: "2016-03-13 16:30"}),

  // All day timespan event
  genEvent({start: "2016-03-15 00:00", end: "2016-03-16 00:00"}),

  // All day datespan
  genEvent({start: "2016-03-17", end: "2016-03-18", object: "datespan"}),

  // Overlapping all day
  genEvent({start: "2016-03-19", end: "2016-03-20", object: "datespan"}),
  genEvent({start: "2016-03-19 00:00", end: "2016-03-20 00:00"}),
  genEvent({start: "2016-03-19 12:00", end: "2016-03-20 12:00"}),
  genEvent({start: "2016-03-20 00:00", end: "2016-03-21 00:00"}),
]
