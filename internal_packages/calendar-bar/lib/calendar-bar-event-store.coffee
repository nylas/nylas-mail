Reflux = require 'reflux'
_ = require 'underscore'
{DatabaseStore,
 AccountStore,
 Actions,
 Event,
 Calendar,
 NylasAPI} = require 'nylas-exports'
moment = require 'moment'

CalendarBarEventStore = Reflux.createStore
  init: ->
    @_setStoreDefaults()
    @_registerListeners()
    @_populate()
    @trigger(@)

  ########### PUBLIC #####################################################

  events: ->
    @_events

  range: ->
    @_range

  ########### PRIVATE ####################################################

  _setStoreDefaults: ->
    @_events = []

  _registerListeners: ->
    @listenTo DatabaseStore, @_onDataChanged
    @listenTo AccountStore, @_onAccountChanged

  _populate: ->
    @_range =
      start: moment({hour: 0, milliseconds: -1}).valueOf() / 1000.0
      end: moment({hour: 24, milliseconds: 1}).valueOf() / 1000.0

    account = AccountStore.current()
    return unless account

    DatabaseStore.findAll(Event, accountId: account.id).where([
      Event.attributes.end.greaterThan(@_range.start),
      Event.attributes.start.lessThan(@_range.end)
    ]).order(Event.attributes.start.ascending()).then (events) =>
      @_events = events
      @trigger(@)

  _refetchFromAPI: ->
    account = AccountStore.current()
    return unless account

    # Trigger a request to the API
    oneDayAgo = Math.round(moment({hour: 0, milliseconds: -1}).valueOf() / 1000.0)
    DatabaseStore.findAll(Calendar, accountId: account.id).then (calendars) ->
      calendars.forEach (calendar) ->
        NylasAPI.getCollection(account.id, 'events', {calendar_id: calendar.id, ends_after: oneDayAgo})

  # Inbound Events

  _onAccountChanged: ->
    @_refetchFromAPI()
    @_populate()

  _onDataChanged: (change) ->
    if change.objectClass == Calendar.name
      @_refetchFromAPI()
    if change.objectClass == Event.name
      @_populate()

module.exports = CalendarBarEventStore
