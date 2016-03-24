React = require 'react'
{Utils} = require 'nylas-exports'

class SendingProgressBar extends React.Component
  @propTypes:
    progress: React.PropTypes.number.isRequired

  render: ->
    otherProps = Utils.fastOmit(@props, Object.keys(@constructor.propTypes))
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
