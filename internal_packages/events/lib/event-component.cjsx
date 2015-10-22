_ = require 'underscore'
path = require 'path'
React = require 'react'
{RetinaImg} = require 'nylas-component-kit'
{Actions,
Event,
Utils,
ComponentRegistry,
AccountStore} = require 'nylas-exports'
EventRSVPTask = require './tasks/event-rsvp'
moment = require 'moment-timezone'

class EventComponent extends React.Component
  @displayName: 'EventComponent'

  @propTypes:
    event: React.PropTypes.object.isRequired

  constructor: (@props) ->
    # Since getting state is asynchronous, default to empty values
    @state = @_nullEvent()

  _nullEvent: ->
    participants: []
    title: ""
    when: {start_time: 0}

  _onChange: =>
    DatabaseStore.find(Event, @props.event.id).then (event) =>
      event ?= @_nullEvent()
      @setState(event)

  componentDidMount: -> @_onChange()

  componentWillMount: ->
    @usubs.push DatabaseStore.listen (change) =>
      @_onChange() if change.objectClass is Event.name
    @usubs.push AccountStore.listen(@_onChange)

  componentWillUnmount: -> usub?() for usub in @usubs()

  _myStatus: =>
    myEmail = AccountStore.current()?.me().email
    for p in @state.participants
      if p['email'] == myEmail
        return p['status']

    return null

  render: =>
    <div className="event-wrapper">
      <div className="event-header">
        <RetinaImg name="icon-RSVP-calendar-mini@2x.png"
                   mode={RetinaImg.Mode.ContentPreserve}/>
        <span className="event-title-text">Event: </span><span className="event-title">{@state.title}</span>
      </div>
      <div className="event-body">
        <div className="event-date">
          <div className="event-day">
            {moment(@state.when['start_time']*1000).tz(Utils.timeZone).format("dddd, MMMM Do")}
          </div>
          <div>
            <div className="event-time">
              {moment(@state.when['start_time']*1000).tz(Utils.timeZone).format("h:mm a z")}
            </div>
            {@_renderEventActions()}
          </div>
        </div>
      </div>
    </div>

  _renderEventActions: =>
    <div className="event-actions">
      {@_renderAcceptButton()}
      {@_renderMaybeButton()}
      {@_renderDeclineButton()}
    </div>

  _renderAcceptButton: ->
    classes = "btn-rsvp"
    if @_myStatus() == "yes"
      classes += " yes"
    <div className=classes onClick={=> @_rsvp("yes")}>
      Accept
    </div>

  _renderDeclineButton: ->
    classes = "btn-rsvp"
    if @_myStatus() == "no"
      classes += " no"
    <div className=classes onClick={=> @_rsvp("no")}>
      Decline
    </div>

  _renderMaybeButton: ->
    classes = "btn-rsvp"
    if @_myStatus() == "maybe"
      classes += " maybe"
    <div className=classes onClick={=> @_rsvp("maybe")}>
      Maybe
    </div>

  _rsvp: (status) ->
    Acitions.queueTask(new EventRSVPTask(@state, status))


module.exports = EventComponent
