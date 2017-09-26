import moment from 'moment';

import Model from './model';
import Attributes from '../attributes';
import Contact from './contact';

// the Chrono node module is huge
let chrono = null;

export default class Event extends Model {
  static attributes = Object.assign({}, Model.attributes, {
    calendarId: Attributes.String({
      queryable: true,
      modelKey: 'calendarId',
      jsonKey: 'calendar_id',
    }),
    title: Attributes.String({
      modelKey: 'title',
      jsonKey: 'title',
    }),
    description: Attributes.String({
      modelKey: 'description',
      jsonKey: 'description',
    }),
    // Can Have 1 of 4 types of subobjects. The Type can be:
    //
    // time
    //   object: "time"
    //   time: (unix timestamp)
    //
    // timestamp
    //   object: "timestamp"
    //   start_time: (unix timestamp)
    //   end_time: (unix timestamp)
    //
    // date
    //   object: "date"
    //   date: (ISO 8601 date format. i.e. 1912-06-23)
    //
    // datespan
    //   object: "datespan"
    //   start_date: (ISO 8601 date)
    //   end_date: (ISO 8601 date)
    when: Attributes.Object({
      modelKey: 'when',
    }),

    location: Attributes.String({
      modelKey: 'location',
      jsonKey: 'location',
    }),

    owner: Attributes.String({
      modelKey: 'owner',
      jsonKey: 'owner',
    }),

    // Subobject:
    // name (string) - The participant's full name (optional)
    // email (string) - The participant's email address
    // status (string) - Attendance status. Allowed values are yes, maybe,
    //                   no and noreply. Defaults is noreply
    // comment (string) - A comment by the participant (optional)
    participants: Attributes.Object({
      modelKey: 'participants',
      jsonKey: 'participants',
    }),
    status: Attributes.String({
      modelKey: 'status',
      jsonKey: 'status',
    }),
    readOnly: Attributes.Boolean({
      modelKey: 'readOnly',
      jsonKey: 'read_only',
    }),
    busy: Attributes.Boolean({
      modelKey: 'busy',
      jsonKey: 'busy',
    }),

    // Has a sub object of the form:
    // rrule: (array) - Array of recurrence rule (RRULE) strings. See RFC-2445
    // timezone: (string) - IANA time zone database formatted string
    //                      (e.g. America/New_York)
    recurrence: Attributes.Object({
      modelKey: 'recurrence',
      jsonKey: 'recurrence',
    }),

    // ----  EXTRACTED ATTRIBUTES -----

    // The "object" type of the "when" object. Can be either "time",
    // "timestamp", "date", or "datespan"
    type: Attributes.String({
      modelKey: 'type',
      jsonKey: '_type',
    }),

    // The calculated Unix start time. See the implementation for how we
    // treat each type of "when" attribute.
    start: Attributes.Number({
      queryable: true,
      modelKey: 'start',
      jsonKey: '_start',
    }),

    // The calculated Unix end time. See the implementation for how we
    // treat each type of "when" attribute.
    end: Attributes.Number({
      queryable: true,
      modelKey: 'end',
      jsonKey: '_end',
    }),

    // This corresponds to the rowid in the FTS table. We need to use the FTS
    // rowid when updating and deleting items in the FTS table because otherwise
    // these operations would be way too slow on large FTS tables.
    searchIndexId: Attributes.Number({
      modelKey: 'searchIndexId',
      jsonKey: 'search_index_id',
    }),
  });

  static searchable = true;

  static searchFields = ['title', 'description', 'location', 'participants'];

  static sortOrderAttribute = () => {
    return Event.attributes.id;
  };

  static naturalSortOrder = () => {
    return Event.sortOrderAttribute().descending();
  };

  // We use moment to parse the date so we can more easily pick up the
  // current timezone of the current locale.
  // We also create a start and end times that span the full day without
  // bleeding into the next.
  _unixRangeForDatespan(startDate, endDate) {
    return {
      start: moment(startDate).unix(),
      end: moment(endDate)
        .add(1, 'day')
        .subtract(1, 'second')
        .unix(),
    };
  }

  fromJSON(json) {
    super.fromJSON(json);

    const when = this.when;

    if (!when) {
      return this;
    }

    if (when.time) {
      this.start = when.time;
      this.end = when.time;
    } else if (when.start_time && when.end_time) {
      this.start = when.start_time;
      this.end = when.end_time;
    } else if (when.date) {
      const range = this._unixRangeForDatespan(when.date, when.date);
      this.start = range.start;
      this.end = range.end;
    } else if (when.start_date && when.end_date) {
      const range = this._unixRangeForDatespan(when.start_date, when.end_date);
      this.start = range.start;
      this.end = range.end;
    }

    return this;
  }

  fromDraft(draft) {
    if (!this.title || this.title.length === 0) {
      this.title = draft.subject;
    }

    if (!this.participants || this.participants.length === 0) {
      this.participants = draft.participants().map(contact => {
        return {
          name: contact.name,
          email: contact.email,
          status: 'noreply',
        };
      });
    }
    return this;
  }

  isAllDay() {
    const daySpan = 86400 - 1;
    return this.end - this.start >= daySpan;
  }

  displayTitle() {
    const displayTitle = this.title.replace(/.*Invitation: /, '');
    const [displayTitleWithoutDate, date] = displayTitle.split(' @ ');
    if (!chrono) {
      chrono = require('chrono-node').default; //eslint-disable-line
    }
    if (date && chrono.parseDate(date)) {
      return displayTitleWithoutDate;
    }
    return displayTitle;
  }

  participantForMe = () => {
    for (const p of this.participants) {
      if (new Contact({ email: p.email }).isMe()) {
        return p;
      }
    }
    return null;
  };
}
