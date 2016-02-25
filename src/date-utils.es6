/** @babel */
import moment from 'moment'
import chrono from 'chrono-node'
import _ from 'underscore'

function isPastDate({year, month, day}, ref) {
  const refDay = ref.getDate();
  const refMonth = ref.getMonth() + 1;
  const refYear = ref.getFullYear();
  if (refYear > year) {
    return true;
  }
  if (refMonth > month) {
    return true;
  }
  if (refDay > day) {
    return true;
  }
  return false;
}

const EnforceFutureDate = new chrono.Refiner();
EnforceFutureDate.refine = (text, results)=> {
  results.forEach((result)=> {
    const current = _.extend({}, result.start.knownValues, result.start.impliedValues);

    if (result.start.isCertain('weekday') && !result.start.isCertain('day')) {
      if (isPastDate(current, result.ref)) {
        result.start.imply('day', result.start.impliedValues.day + 7);
      }
    }

    if (result.start.isCertain('day') && !result.start.isCertain('month')) {
      if (isPastDate(current, result.ref)) {
        result.start.imply('month', result.start.impliedValues.month + 1);
      }
    }
    if (result.start.isCertain('month') && !result.start.isCertain('year')) {
      if (isPastDate(current, result.ref)) {
        result.start.imply('year', result.start.impliedValues.year + 1);
      }
    }
  });
  return results;
};

const chronoFuture = new chrono.Chrono(chrono.options.casualOption());
chronoFuture.refiners.push(EnforceFutureDate);

const Hours = {
  Morning: 9,
  Evening: 20,
  Midnight: 24,
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

function midnight(momentDate, midnightHour = Hours.Midnight) {
  return oclock(momentDate.hour(midnightHour))
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
      return midnight(now);
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
  futureDateFromString(dateLikeString) {
    const date = chronoFuture.parseDate(dateLikeString)
    if (!date) {
      return null
    }
    return moment(date)
  },
}

export default DateUtils
