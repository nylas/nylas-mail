Model = require './model'
Contact = require './contact'
Attributes = require '../attributes'
_ = require 'underscore'
moment = require('moment')

class Event extends Model

  @attributes: _.extend {}, Model.attributes,
    'calendarId': Attributes.String
      queryable: true
      modelKey: 'calendarId'
      jsonKey: 'calendar_id'

    'title': Attributes.String
      modelKey: 'title'
      jsonKey: 'title'

    'description': Attributes.String
      modelKey: 'description'
      jsonKey: 'description'

    # Can Have 1 of 4 types of subobjects. The Type can be:
    #
    # time
    #   object: "time"
    #   time: (unix timestamp)
    #
    # timestamp
    #   object: "timestamp"
    #   start_time: (unix timestamp)
    #   end_time: (unix timestamp)
    #
    # date
    #   object: "date"
    #   date: (ISO 8601 date format. i.e. 1912-06-23)
    #
    # datespan
    #   object: "datespan"
    #   start_date: (ISO 8601 date)
    #   end_date: (ISO 8601 date)
    'when': Attributes.Object
      modelKey: 'when'

    'location': Attributes.String
      modelKey: 'location'
      jsonKey: 'location'

    'owner': Attributes.String
      modelKey: 'owner'
      jsonKey: 'owner'

    ## Subobject:
    # name (string) - The participant's full name (optional)
    # email (string) - The participant's email address
    # status (string) - Attendance status. Allowed values are yes, maybe,
    #                   no and noreply. Defaults is noreply
    # comment (string) - A comment by the participant (optional)
    'participants': Attributes.Object
      modelKey: 'participants'
      jsonKey: 'participants'

    'status': Attributes.String
      modelKey: 'status'
      jsonKey: 'status'

    'readOnly': Attributes.Boolean
      modelKey: 'readOnly'
      jsonKey: 'read_only'

    'busy': Attributes.Boolean
      modelKey: 'busy'
      jsonKey: 'busy'

    # Has a sub object of the form:
    # rrule: (array) - Array of recurrence rule (RRULE) strings. See RFC-2445
    # timezone: (string) - IANA time zone database formatted string
    #                      (e.g. America/New_York)
    'recurrence': Attributes.Object
      modelKey: 'recurrence'
      jsonKey: 'recurrence'

    ################ EXTRACTED ATTRIBUTES ##############

    # The "object" type of the "when" object. Can be either "time",
    # "timestamp", "date", or "datespan"
    'type': Attributes.String
      modelKey: 'type'
      jsonKey: '_type'

    # The calculated Unix start time. See the implementation for how we
    # treat each type of "when" attribute.
    'start': Attributes.Number
      queryable: true
      modelKey: 'start'
      jsonKey: '_start'

    # The calculated Unix end time. See the implementation for how we
    # treat each type of "when" attribute.
    'end': Attributes.Number
      queryable: true
      modelKey: 'end'
      jsonKey: '_end'

  _convertTime: ({time}) ->
    return {start: time, end: time}

  _convertTimespan: ({start_time, end_time}) ->
    DEFAULT_DURATION = 60*60 # 60 minutes
    if start_time and end_time
      return {start: start_time, end: end_time}
    else if start_time and not end_time
      return {start: start_time, end: start_time + DEFAULT_DURATION}
    else if not start_time and end_time
      return {start: end_time - DEFAULT_DURATION, end: end_time}
    else
      return {start: 0, end: DEFAULT_DURATION}

  # We use moment to parse the date so we can more easily pick up the
  # current timezone of the current locale.
  #
  # We also create a start and end times that span the full day without
  # bleeding into the next.
  _convertDate: ({date}) ->
    return {
      start: moment(date).unix()
      end: moment(date).add(1, 'day').subtract(1, 'second').unix()
    }

  _convertDatespan: ({start_date, end_date}) ->
    DEFAULT_DAY = 60*60*24
    if start_date and end_date
      return {
        start: moment(start_date).unix()
        end: moment(end_date).add(1, 'day').subtract(1, 'second').unix()
      }
    else if start_date and not end_date
      return @_convertDate({date: start_date})
    else if not start_date and end_date
      return @_convertDate({date: end_date})
    else
      return {start: 0, end: DEFAULT_DAY}

  fromJSON: (json) ->
    super(json)

    return @ unless @when

    switch @when.object
      when "time"
        {@start, @end} = @_convertTime(@when)
      when "timespan"
        {@start, @end} = @_convertTimespan(@when)
      when "date"
        {@start, @end} = @_convertDate(@when)
      when "datespan"
        {@start, @end} = @_convertDatespan(@when)
      else
        return @
    return @

  isAllDay: ->
    daySpan = 86400 - 1
    (@end - @start) >= daySpan

  participantForMe: =>
    for p in @participants
      if (new Contact(email: p.email)).isMe()
        return p
    return null

module.exports = Event
