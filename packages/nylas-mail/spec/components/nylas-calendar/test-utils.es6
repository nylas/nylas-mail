import moment from 'moment-timezone'

export const TZ = window.TEST_TIME_ZONE;
export const TEST_CALENDAR = "TEST_CALENDAR";

export const now = () => window.testNowMoment();

export const NOW_WEEK_START = moment.tz("2016-03-13 00:00", TZ);
export const NOW_BUFFER_START = moment.tz("2016-03-06 00:00", TZ);
export const NOW_BUFFER_END = moment.tz("2016-03-26 23:59:59", TZ);

// Makes test failure output easier to read.
export const u2h = (unixTime) => moment.unix(unixTime).format("LLL z")
export const m2h = (m) => m.format("LLL z")
