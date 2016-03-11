import React from 'react'
import {Utils, Actions} from 'nylas-exports'

export default class RelatedThreads extends React.Component {
  static displayName = "RelatedThreads";

  static propTypes = {
    contact: React.PropTypes.object,
    contactThreads: React.PropTypes.array,
  }

  constructor(props) {
    super(props)
    this.state = {expanded: false}
    this.DEFAULT_NUM = 3
  }

  static containerStyles = {
    order: 99,
  }

  _onClick(thread) {
    Actions.setFocus({collection: 'thread', item: thread})
  }

  _toggle = () => {
    this.setState({expanded: !this.state.expanded})
  }

  _renderToggle() {
    if (!this._hasToggle()) { return false; }
    const msg = this.state.expanded ? "Collapse" : "Show more"
    return (
      <div className="toggle" onClick={this._toggle}>{msg}</div>
    )
  }

  _hasToggle() {
    return (this.props.contactThreads.length > this.DEFAULT_NUM)
  }

  render() {
    let limit;
    if (this.state.expanded) {
      limit = this.props.contactThreads.length;
    } else {
      limit = Math.min(this.props.contactThreads.length, this.DEFAULT_NUM)
    }

    const height = ((limit + (this._hasToggle() ? 1 : 0)) * 31);
    const shownThreads = this.props.contactThreads.slice(0, limit)
    const threads = shownThreads.map((thread) => {
      const onClick = () => { this._onClick(thread) }
      return (
        <div key={thread.id} className="related-thread" onClick={onClick} >
          <span className="subject" title={thread.subject}>{thread.subject}</span>
          <span className="timestamp" title={Utils.fullTimeString(thread.lastMessageReceivedTimestamp)}>{Utils.shortTimeString(thread.lastMessageReceivedTimestamp)}</span>
        </div>
      )
    })

    return (
      <div className="related-threads" style={{height}}>
        {threads}
        {this._renderToggle()}
      </div>
    )
  }
}
