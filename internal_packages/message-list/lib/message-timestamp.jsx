import React from 'react'
import {DateUtils} from 'nylas-exports'

class MessageTimestamp extends React.Component {
  static displayName = 'MessageTimestamp'

  static propTypes = {
    date: React.PropTypes.object.isRequired,
    className: React.PropTypes.string,
    isDetailed: React.PropTypes.bool,
    onClick: React.PropTypes.func,
  }

  shouldComponentUpdate(nextProps) {
    return (
      nextProps.date !== this.props.date ||
      nextProps.isDetailed !== this.props.isDetailed
    )
  }

  render() {
    let formattedDate = null
    if (this.props.isDetailed) {
      formattedDate = DateUtils.mediumTimeString(this.props.date)
    } else {
      formattedDate = DateUtils.shortTimeString(this.props.date)
    }
    return (
      <div
        className={this.props.className}
        title={DateUtils.fullTimeString(this.props.date)}
        onClick={this.props.onClick}
      >
        {formattedDate}
      </div>
    )
  }
}

export default MessageTimestamp
