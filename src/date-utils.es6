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

moment().__proto__.oclock = function oclock() {
  return this.minute(0).second(0)
}

moment().__proto__.morning = function morning(morningHour = Hours.Morning) {
  return this.hour(morningHour).oclock()
}

moment().__proto__.evening = function evening(eveningHour = Hours.Evening) {
  return this.hour(eveningHour).oclock()
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
    return now.add(3, 'hours').oclock();
  },

  tonight(now = moment()) {
    if (now.hour() >= Hours.Evening) {
      return DateUtils.tomorrowEvening();
    }
    return now.evening();
  },

  tomorrow(now = moment()) {
    return now.add(1, 'day').morning();
  },

  tomorrowEvening(now = moment()) {
    return now.add(1, 'day').evening()
  },

  thisWeekend(now = moment()) {
    return now.day(Days.ThisWeekend).morning()
  },

  nextWeek(now = moment()) {
    return now.day(Days.NextMonday).morning()
  },

  nextMonth(now = moment()) {
    return now.add(1, 'month').date(1).morning()
  },

  /**
   * Can take almost any string.
   * e.g. "Next monday at 2pm"
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
