React = require 'react'
_ = require 'underscore-plus'

module.exports =
Spinner = React.createClass
  propTypes:
    visible: React.PropTypes.bool
    style: React.PropTypes.object

  getInitialState: ->
    hidden: true
    paused: true

  componentDidMount: ->
    # The spinner always starts hidden. After it's mounted, it unhides itself
    # if it's set to visible. This is a bit strange, but ensures that the CSS
    # transition from .spinner.hidden => .spinner always happens, along with
    # it's associated animation delay.
    if @props.visible and @state.hidden
      @showAfterDelay()

  componentWillReceiveProps: (nextProps) ->
    hidden = if nextProps.visible? then !nextProps.visible else false

    if @state.hidden is false and hidden is true
      @setState({hidden: true})
      @pauseAfterDelay()
    else if @state.hidden is true and hidden is false
      @showAfterDelay()

  pauseAfterDelay: ->
    _.delay =>
      return unless @isMounted()
      return if @props.visible
      @setState({paused: true})
    ,250

  showAfterDelay: ->
    _.delay =>
      return unless @isMounted()
      return if @props.visible isnt true
      @setState({paused: false, hidden: false})
    , 300

  render: ->
    spinnerClass = React.addons.classSet
      'spinner': true
      'hidden': @state.hidden
      'paused': @state.paused

    style = _.extend @props.style ? {},
      'position':'absolute'
      'left': '50%'
      'top': '50%'
      'transform':'translate(-50%,-50%);'

    otherProps = _.omit(@props, _.keys(@constructor.propTypes))

    <div className={spinnerClass} {...otherProps} style={style}>
      <div className="bounce1"></div>
      <div className="bounce2"></div>
      <div className="bounce3"></div>
    </div>