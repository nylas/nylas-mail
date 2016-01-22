Task = require './task'
Event = require '../models/event'
{APIError} = require '../errors'
Utils = require '../models/utils'
DatabaseStore = require '../stores/database-store'
AccountStore = require '../stores/account-store'
Actions = require '../actions'
NylasAPI = require '../nylas-api'

module.exports =
class EventRSVPTask extends Task
  constructor: (@event, @RSVPEmail, @RSVPResponse) ->
    super

  performLocal: ->
    DatabaseStore.inTransaction (t) =>
      t.find(Event, @event.id).then (updated) =>
        @event = updated ? @event
        @_previousParticipantsState = Utils.deepClone(@event.participants)

        for p in @event.participants
          if p.email is @RSVPEmail
            p.status = @RSVPResponse

        t.persistModel(@event)

  performRemote: ->
    NylasAPI.makeRequest
      path: "/send-rsvp"
      accountId: @event.accountId
      method: "POST"
      body: {
        event_id: @event.id,
        status: @RSVPResponse
      }
      returnsModel: true
    .thenReturn(Task.Status.Success)
    .catch APIError, (err) =>
      @event.participants = @_previousParticipantsState
      DatabaseStore.inTransaction (t) =>
        t.persistModel(@event)
      .thenReturn(Task.Status.Failed)

  onOtherError: -> Promise.resolve()
  onTimeoutError: -> Promise.resolve()
  onOfflineError: -> Promise.resolve()
