_ = require 'underscore'
path = require 'path'
React = require 'react'
{RetinaImg} = require 'nylas-component-kit'
{Actions,
 Message,
 Event,
 Utils,
 ComponentRegistry,
 EventRSVPTask,
 DatabaseStore,
 AccountStore} = require 'nylas-exports'
moment = require 'moment-timezone'

class EventHeader extends React.Component
  @displayName: 'EventHeader'

  @propTypes:
    message: React.PropTypes.instanceOf(Message).isRequired

  constructor: (@props) ->
    @state =
      event: @props.message.events[0]

  _onChange: =>
    return unless @state.event
    DatabaseStore.find(Event, @state.event.id).then (event) =>
      return unless event
      @setState({event})

  componentDidMount: =>
    # TODO: This should use observables!
    @_unlisten = DatabaseStore.listen (change) =>
      if @state.event and change.objectClass is Event.name
        updated = _.find change.objects, (o) => o.id is @state.event.id
        @setState({event: updated}) if updated
    @_onChange()

  componentWillReceiveProps: (nextProps) =>
    @setState({event:nextProps.message.events[0]})
    @_onChange()

  componentWillUnmount: =>
    @_unlisten?()

  render: =>
    if @state.event?
      <div className="event-wrapper">
        <div className="event-header">
          <RetinaImg name="icon-RSVP-calendar-mini@2x.png"
                     mode={RetinaImg.Mode.ContentPreserve}/>
          <span className="event-title-text">Event: </span><span className="event-title">{@state.event.title}</span>
        </div>
        <div className="event-body">
          <div className="event-date">
            <div className="event-day">
              {moment(@state.event.start*1000).tz(Utils.timeZone).format("dddd, MMMM Do")}
            </div>
            <div>
              <div className="event-time">
                {moment(@state.event.start*1000).tz(Utils.timeZone).format("h:mm a z")}
              </div>
              {@_renderEventActions()}
            </div>
          </div>
        </div>
      </div>
    else
      <div></div>

  _renderEventActions: =>
    me = @state.event.participantForMe()
    return false unless me

    actions = [["yes", "Accept"], ["maybe", "Maybe"], ["no", "Decline"]]

    <div className="event-actions">
      {actions.map ([status, label]) =>
        classes = "btn-rsvp "
        classes += status if me.status is status
        <div key={status} className={classes} onClick={=> @_rsvp(status)}>
          {label}
        </div>
      }
    </div>

  _rsvp: (status) =>
    me = @state.event.participantForMe()
    Actions.queueTask(new EventRSVPTask(@state.event, me.email, status))

module.exports = EventHeader
