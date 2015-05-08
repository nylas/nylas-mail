React = require 'react'
_ = require "underscore-plus"
moment = require 'moment'
classNames = require 'classnames'

class TodayIcon extends React.Component
  @displayName: 'TodayIcon'

  constructor: (@props) ->
    @state =
      moment: moment()

  componentDidMount: =>
    @_setTimeState()

  componentWillUnmount: =>
    clearInterval(@_timer)

  render: =>
    classes = classNames
      'today-icon': true
      'selected': @props.selected

    <div className={classes}>{@state.moment.format('D')}</div>

  _setTimeState: =>
    timeTillNextSecond = (60 - (new Date).getSeconds()) * 1000
    @_timer = setTimeout(@_setTimeState, timeTillNextSecond)
    @setState(moment: moment())


module.exports = TodayIcon
