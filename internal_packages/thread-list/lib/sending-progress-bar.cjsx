React = require 'react'
_ = require 'underscore'

class SendingProgressBar extends React.Component
  @propTypes:
    progress: React.PropTypes.number.isRequired

  render: ->
    otherProps = _.omit(@props, _.keys(@constructor.propTypes))
    if 0 < @props.progress < 99
      <div className="sending-progress" {...otherProps}>
        <div className="filled"
             style={width:"#{Math.min(100, @props.progress)}%"}>
        </div>
      </div>
    else
      <div className="sending-progress" {...otherProps}>
        <div className="indeterminate"></div>
      </div>

module.exports = SendingProgressBar
