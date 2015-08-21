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
    DatabaseStore.find(Event, @event.id).then (e) =>
      e ?= @event
      @_previousParticipantsState = Utils.deepClone(e.participants)
      participants = []
      for p in e.participants
        if p['email'] == @myEmail
          p['status'] = @RSVPResponse
        participants.push p
      e.participants = participants
      @event = e
      DatabaseStore.persistModel(e)

  performRemote: ->
    new Promise (resolve, reject) =>
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
        return Promise.resolve(Task.Status.Finished)
      .catch APIError, (err) =>
        ##TODO: event already accepted/declined/etc
        @event.participants = @_previousParticipantsState
        DatabaseStore.persistModel(@event).then(resolve).catch(reject)

  onOtherError: -> Promise.resolve()
  onTimeoutError: -> Promise.resolve()
  onOfflineError: -> Promise.resolve()
