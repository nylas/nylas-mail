import moment from 'moment-timezone'
import chrono from 'chrono-node'
import _ from 'underscore'

// Init locale for moment
moment.locale(navigator.language)

// Initialise moment timezone
const tz = moment.tz.guess()
if (!tz) {
  console.error("DateUtils: TimeZone could not be determined. This should not happen!")
}

const yearRegex = / ?YY(YY)?/

const Hours = {
  Morning: 9,
  Evening: 20,
  Midnight: 24,
}

const Days = {
  // The value for next monday and next weekend varies depending if the current
  // day is saturday or sunday. See http://momentjs.com/docs/#/get-set/day/
  NextMonday: day => (day === 0 ? 1 : 8),
  ThisWeekend: day => (day === 6 ? 13 : 6),
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

function isPastDate(inputDateObj, currentDate) {
  const inputMoment = moment({...inputDateObj, month: inputDateObj.month - 1})
  const currentMoment = moment(currentDate)

  return inputMoment.isBefore(currentMoment)
}

const EnforceFutureDate = new chrono.Refiner();
EnforceFutureDate.refine = (text, results) => {
  results.forEach((result) => {
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


const DateUtils = {

  // Localized format: ddd, MMM D, YYYY h:mmA
  DATE_FORMAT_LONG: 'llll',

  DATE_FORMAT_LONG_NO_YEAR: moment.localeData().longDateFormat('llll').replace(yearRegex, ''),

  // Localized format: MMM D, h:mmA
  DATE_FORMAT_SHORT: moment.localeData().longDateFormat('lll').replace(yearRegex, ''),

  DATE_FORMAT_llll_NO_TIME: moment.localeData().longDateFormat("llll").replace(/h:mm/, "").replace(" A", ""),

  DATE_FORMAT_LLLL_NO_TIME: moment.localeData().longDateFormat("LLLL").replace(/h:mm/, "").replace(" A", ""),

  timeZone: tz,

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

  hoursFromNow(hours, now = moment()) {
    return now.add(hours, 'hours');
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
    return morning(now.day(Days.ThisWeekend(now.day())))
  },

  weeksFromNow(weeks, now = moment()) {
    return now.add(weeks, 'weeks');
  },

  nextWeek(now = moment()) {
    return morning(now.day(Days.NextMonday(now.day())))
  },

  monthsFromNow(months, now = moment()) {
    return now.add(months, 'months');
  },

  nextMonth(now = moment()) {
    return morning(now.add(1, 'month').date(1))
  },

  parseDateString(dateLikeString) {
    const parsed = chrono.parse(dateLikeString)
    const gotTime = {start: false, end: false};
    const gotDay = {start: false, end: false};
    const now = moment();
    const results = {start: moment(now), end: moment(now), leftoverText: dateLikeString};
    for (const item of parsed) {
      for (const val of ['start', 'end']) {
        if (!(val in item)) {
          continue;
        }
        const {day: knownDay, weekday: knownWeekday, hour: knownHour} = item[val].knownValues;
        const {year, month, day, hour, minute} = Object.assign(item[val].knownValues, item[val].impliedValues)
        if (!gotTime[val] && knownHour) {
          gotTime[val] = true;
          results[val].minute(minute)
          results[val].hour(hour)

          if (!gotDay[val]) {
            results[val].date(day)
            results[val].month(month - 1) // moment zero-indexes month
            results[val].year(year)
          }

          results.leftoverText = results.leftoverText.replace(item.text, '')
        }
        if (!gotDay[val] && (knownDay || knownWeekday)) {
          gotDay[val] = true
          results[val].year(year)
          results[val].month(month - 1) // moment zero-indexes month
          results[val].date(day)

          if (!gotTime) {
            results[val].hour(hour)
            results[val].minute(minute)
          }

          results.leftoverText = results.leftoverText.replace(item.text, '')
        }
      }
    }

    // Make the event a default 1 hour long if it looks like the end date
    // wasn't assigned, or if it's before the start date.
    if (results.end.valueOf() === now.valueOf() || results.end <= results.start) {
      results.end = moment(results.start);
      results.end.hour(results.end.hour() + 1);
    }

    return results;
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
    const inThePast = date.valueOf() < Date.now()
    if (inThePast) {
      return null
    }
    return moment(date)
  },


  /**
   * Return a formatting string for displaying time
   *
   * @param {Date} opts - Object with different properties for customising output
   * @return {String} The format string based on syntax used by Moment.js
   *
   * seconds, upperCase and timeZone are the supported extra options to the format string.
   * Checks whether or not to use 24 hour time format.
   */
  getTimeFormat(opts) {
    const use24HourClock = NylasEnv.config.get('core.workspace.use24HourClock')
    let timeFormat = use24HourClock ? "HH:mm" : "h:mm"

    if (opts && opts.seconds) {
      timeFormat += ":ss"
    }

    // Append meridian if not using 24 hour clock
    if (!use24HourClock) {
      if (opts && opts.upperCase) {
        timeFormat += " A"
      } else {
        timeFormat += " a"
      }
    }

    if (opts && opts.timeZone) {
      timeFormat += " z"
    }

    return timeFormat
  },


  /**
   * Return a short format date/time
   *
   * @param {Date} datetime - Timestamp
   * @return {String} Formated date/time
   *
   * The returned date/time format depends on how long ago the timestamp is.
   */
  shortTimeString(datetime) {
    const now = moment()
    const diff = now.diff(datetime, 'days', true)
    const isSameDay = now.isSame(datetime, 'days')
    let format = null

    if (diff <= 1 && isSameDay) {
      // Time if less than 1 day old
      format = DateUtils.getTimeFormat(null)
    } else if (diff < 2 && !isSameDay) {
      // Month and day with time if up to 2 days ago
      format = `MMM D, ${DateUtils.getTimeFormat(null)}`
    } else if (diff >= 2 && diff < 365) {
      // Month and day up to 1 year old
      format = "MMM D"
    } else {
      // Month, day and year if over a year old
      format = "MMM D YYYY"
    }

    return moment(datetime).format(format)
  },


  /**
   * Return a medium format date/time
   *
   * @param {Date} datetime - Timestamp
   * @return {String} Formated date/time
   */
  mediumTimeString(datetime) {
    let format = "MMMM D, YYYY, "
    format += DateUtils.getTimeFormat({seconds: false, upperCase: true, timeZone: false})

    return moment(datetime).format(format)
  },


  /**
   * Return a long format date/time
   *
   * @param {Date} datetime - Timestamp
   * @return {String} Formated date/time
   */
  fullTimeString(datetime) {
    let format = "dddd, MMMM Do YYYY, "
    format += DateUtils.getTimeFormat({seconds: true, upperCase: true, timeZone: true})

    return moment(datetime).tz(tz).format(format)
  },

};

export default DateUtils
