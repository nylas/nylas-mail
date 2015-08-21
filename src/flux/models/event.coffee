Model = require './model'
Contact = require './contact'
Attributes = require '../attributes'
_ = require 'underscore'

class Event extends Model

  @attributes: _.extend {}, Model.attributes,
    'id': Attributes.String
      queryable: true
      modelKey: 'id'
      jsonKey: 'id'

    'accountId': Attributes.String
      modelKey: 'accountId'
      jsonKey: 'accountId'

    'title': Attributes.String
      modelKey: 'title'
      jsonKey: 'title'

    'description': Attributes.String
      modelKey: 'description'
      jsonKey: 'description'

    'location': Attributes.String
      modelKey: 'location'
      jsonKey: 'location'

    'participants': Attributes.Object
      modelKey: 'participants'
      jsonKey: 'participants'

    'when': Attributes.Object
      modelKey: 'when'

    'start': Attributes.Number
      queryable: true
      modelKey: 'start'
      jsonKey: '_start'

    'end': Attributes.Number
      queryable: true
      modelKey: 'end'
      jsonKey: '_end'

  fromJSON: (json) ->
    super(json)

    # For indexing and querying purposes, we flatten the start and end of the different
    # "when" formats into two timestamps we can use for range querying. Note that for
    # all-day events, we use first second of start date and last second of end date.
    @start = @when.start_time || new Date(@when.start_date).getTime()/1000.0 || @when.time
    @end = @when.end_time || new Date(@when.end_date).getTime()/1000.0+(60*60*24-1) || @when.time
    delete @when.object
    @

module.exports = Event
