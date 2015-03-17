React = require 'react'
_ = require 'underscore-plus'

module.exports =
Spinner = React.createClass
  propTypes:
    visible: React.PropTypes.bool
    style: React.PropTypes.object

  getInitialState: ->
    hidden: false
    paused: false

  componentWillReceiveProps: (nextProps) ->
    hidden = if nextProps.visible? then !nextProps.visible else false

    if @state.hidden is false and hidden is true
      @setState({hidden: true})
      setTimeout =>
        return unless @isMounted()
        @setState({paused: true})
      ,250
    else if @state.hidden is true and hidden is false
      @setState({paused: false, hidden: false})

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