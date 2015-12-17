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
  constructor: (calendar_event, @RSVPResponse) ->
    @myEmail = AccountStore.current()?.me().email.toLowerCase().trim()
    @event = calendar_event
    super

  performLocal: ->
    DatabaseStore.inTransaction (t) =>
      t.find(Event, @event.id).then (e) =>
        e ?= @event
        @_previousParticipantsState = Utils.deepClone(e.participants)
        participants = []
        for p in e.participants
          if p['email'] == @myEmail
            p['status'] = @RSVPResponse
          participants.push p
        e.participants = participants
        @event = e
        t.persistModel(e)

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
    .then =>
      return Promise.resolve(Task.Status.Success)
    .catch APIError, (err) =>
      ##TODO event already accepted/declined/etc
      @event.participants = @_previousParticipantsState
      DatabaseStore.inTransaction (t) =>
        t.persistModel(@event).then ->
          return Promise.resolve(Task.Status.Failed)
        .catch (err) ->
          return Promise.resolve(Task.Status.Failed)

  onOtherError: -> Promise.resolve()
  onTimeoutError: -> Promise.resolve()
  onOfflineError: -> Promise.resolve()
