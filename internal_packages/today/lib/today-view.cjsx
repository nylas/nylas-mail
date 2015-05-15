React = require 'react'
_ = require "underscore-plus"
{Utils, Actions} = require 'nylas-exports'
{Spinner, EventedIFrame} = require 'nylas-component-kit'
moment = require 'moment'

class TodayViewDateTime extends React.Component
  @displayName: 'TodayViewDateTime'

  constructor: (@props) ->
    @state =
      moment: moment()

  componentDidMount: =>
    @_setTimeState()

  componentWillUnmount: =>
    clearInterval(@_timer)

  render: =>
    <div className="centered">
      <div className="time">{@state.moment.format('h:mm')}</div>
      <div className="date">{@state.moment.format('dddd, MMM Do')}</div>
    </div>

  _setTimeState: =>
    timeTillNextSecond = (60 - (new Date).getSeconds()) * 1000
    @_timer = setTimeout(@_setTimeState, timeTillNextSecond)

    @setState(moment: moment())


class TodayViewBox extends React.Component
  @displayName: 'TodayViewBox'

  @propTypes:
    name: React.PropTypes.string.isRequired

  constructor: (@props) ->

  render: =>
    <div className="box">
      <h2>{@props.name}</h2>
    </div>

class TodayView extends React.Component
  @displayName: 'TodayView'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  render: =>
    <div className="today">
      <div className="inner">
        <TodayViewDateTime />
        <div className="boxes">
          <TodayViewBox name="Conversations">
          </TodayViewBox>
          <TodayViewBox name="Events">
          </TodayViewBox>
          <TodayViewBox name="Drafts">
          </TodayViewBox>
        </div>
        <div className="to-the-inbox">
          Inbox
        </div>
      </div>
    </div>

  componentDidMount: =>
    @_unsubscribers = []

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  _getStateFromStores: =>
    {}
  
  _onChange: =>
    @setState(@_getStateFromStores())


module.exports = TodayView
