/** @babel */
import moment from 'moment'
import chrono from 'chrono-node'

const Hours = {
  Morning: 9,
  Evening: 19,
}

const Days = {
  NextMonday: 8,
  ThisWeekend: 6,
}

function oclock(momentDate) {
  return momentDate.minute(0).second(0)
}

function morning(momentDate, morningHour = Hours.Morning) {
  return oclock(momentDate.hour(morningHour))
}

function evening(momentDate, eveningHour = Hours.Evening) {
  return oclock(momentDate.hour(eveningHour))
}


const DateUtils = {

  format(momentDate, formatString) {
    if (!momentDate) return null;
    return momentDate.format(formatString);
  },

  utc(momentDate) {
    if (!momentDate) return null;
    return momentDate.utc();
  },

  minutesFromNow(minutes, now = moment()) {
    return now.add(minutes, 'minutes');
  },

  in1Hour() {
    return DateUtils.minutesFromNow(60);
  },

  in2Hours() {
    return DateUtils.minutesFromNow(120);
  },

  laterToday(now = moment()) {
    return oclock(now.add(3, 'hours'));
  },

  tonight(now = moment()) {
    if (now.hour() >= Hours.Evening) {
      return DateUtils.tomorrowEvening();
    }
    return evening(now)
  },

  tomorrow(now = moment()) {
    return morning(now.add(1, 'day'));
  },

  tomorrowEvening(now = moment()) {
    return evening(now.add(1, 'day'));
  },

  thisWeekend(now = moment()) {
    return morning(now.day(Days.ThisWeekend))
  },

  nextWeek(now = moment()) {
    return morning(now.day(Days.NextMonday))
  },

  nextMonth(now = moment()) {
    return morning(now.add(1, 'month').date(1))
  },

  /**
   * Can take almost any string.
   * e.g. "Next Monday at 2pm"
   * @param {string} dateLikeString - a string representing a date.
   * @return {moment} - moment object representing date
   */
  fromString(dateLikeString) {
    const date = chrono.parseDate(dateLikeString)
    if (!date) {
      return null
    }
    return moment(date)
  },
}

export default DateUtils
