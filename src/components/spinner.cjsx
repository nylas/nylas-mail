React = require 'react'
_ = require 'underscore-plus'
classNames = require 'classnames'

class Spinner extends React.Component
  @propTypes =
    visible: React.PropTypes.bool
    style: React.PropTypes.object

  constructor: (@props) ->
    @state =
      hidden: true
      paused: true

  componentDidMount: =>
    # The spinner always starts hidden. After it's mounted, it unhides itself
    # if it's set to visible. This is a bit strange, but ensures that the CSS
    # transition from .spinner.hidden => .spinner always happens, along with
    # it's associated animation delay.
    if @props.visible and @state.hidden
      @showAfterDelay()

  componentWillReceiveProps: (nextProps) =>
    hidden = if nextProps.visible? then !nextProps.visible else false

    if @state.hidden is false and hidden is true
      @setState({hidden: true})
      @pauseAfterDelay()
    else if @state.hidden is true and hidden is false
      @showAfterDelay()

  pauseAfterDelay: =>
    _.delay =>
      return if @props.visible
      @setState({paused: true})
    ,250

  showAfterDelay: =>
    _.delay =>
      return if @props.visible isnt true
      @setState({paused: false, hidden: false})
    , 300

  render: =>
    if @props.withCover
      @_renderDotsWithCover()
    else
      @_renderSpinnerDots()

  # This displays an extra div that's a partially transparent white cover.
  # If you don't want to make your own background for the loading state,
  # this is a convenient default.
  _renderDotsWithCover: =>
    coverClasses = React.addons.classSet
      "spinner-cover": true
      "hidden": @state.hidden

    style = _.extend @props.style ? {},
      'position':'absolute'
      'display': if @state.hidden then "none" else "block"
      'top': '0'
      'left': '0'
      'width': '100%'
      'height': '100%'
      'background': 'rgba(255,255,255,0.9)'
      'zIndex': @props.zIndex ? 1000

    <div className={coverClasses} style={style}>
      {@_renderSpinnerDots()}
    </div>

  _renderSpinnerDots: =>
    spinnerClass = classNames
      'spinner': true
      'hidden': @state.hidden
      'paused': @state.paused

    style = _.extend @props.style ? {},
      'position':'absolute'
      'left': '50%'
      'top': '50%'
      'zIndex': @props.zIndex+1 ? 1001
      'transform':'translate(-50%,-50%)'

    otherProps = _.omit(@props, _.keys(@constructor.propTypes))

    <div className={spinnerClass} {...otherProps} style={style}>
      <div className="bounce1"></div>
      <div className="bounce2"></div>
      <div className="bounce3"></div>
    </div>

module.exports = Spinner
