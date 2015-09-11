_ = require 'underscore'
path = require 'path'
React = require 'react'
{RetinaImg} = require 'nylas-component-kit'
{Actions,
Utils,
ComponentRegistry,
EventStore,
AccountStore} = require 'nylas-exports'
moment = require 'moment-timezone'

class EventComponent extends React.Component
  @displayName: 'EventComponent'

  @propTypes:
    event: React.PropTypes.object.isRequired

  constructor: (@props) ->
    @state = @_getStateFromStores()

  _onChange: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    e = EventStore.getEvent(@props.event.id)
    e ?= @props.event

  componentWillMount: ->
    @unsub = EventStore.listen(@_onChange)

  componentWillUnmount: ->
    @unsub()

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
    <div className=classes onClick={@_onClickAccept}>
      Accept
    </div>

  _renderDeclineButton: ->
    classes = "btn-rsvp"
    if @_myStatus() == "no"
      classes += " no"
    <div className=classes onClick={@_onClickDecline}>
      Decline
    </div>

  _renderMaybeButton: ->
    classes = "btn-rsvp"
    if @_myStatus() == "maybe"
      classes += " maybe"
    <div className=classes onClick={@_onClickMaybe}>
      Maybe
    </div>

  _onClickAccept: => Actions.RSVPEvent(@state, "yes")

  _onClickDecline: => Actions.RSVPEvent(@state, "no")

  _onClickMaybe: => Actions.RSVPEvent(@state, "maybe")


module.exports = EventComponent
