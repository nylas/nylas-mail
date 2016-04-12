import React from 'react'
import {Utils} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'

export default class HeaderControls extends React.Component {
  static displayName = "HeaderControls";

  static propTypes = {
    title: React.PropTypes.string,
    headerComponents: React.PropTypes.node,
    nextAction: React.PropTypes.func,
    prevAction: React.PropTypes.func,
  }

  static defaultProps = {
    headerComonents: false,
  }

  shouldComponentUpdate(nextProps, nextState) {
    return (!Utils.isEqualReact(nextProps, this.props) ||
            !Utils.isEqualReact(nextState, this.state));
  }

  _renderNextAction() {
    if (!this.props.nextAction) { return false; }
    return (
      <button className="btn btn-icon next" onClick={this.props.nextAction}>
        <RetinaImg name="ic-calendar-right-arrow.png"
          mode={RetinaImg.Mode.ContentIsMask}
        />
      </button>
    )
  }

  _renderPrevAction() {
    if (!this.props.prevAction) { return false; }
    return (
      <button className="btn btn-icon prev" onClick={this.props.prevAction}>
        <RetinaImg name="ic-calendar-left-arrow.png"
          mode={RetinaImg.Mode.ContentIsMask}
        />
      </button>
    )
  }

  render() {
    return (
      <div className="header-controls">
        <div className="center-controls">
          {this._renderPrevAction()}
          <span className="title">{this.props.title}</span>
          {this._renderNextAction()}
        </div>
        {this.props.headerComponents}
      </div>
    )
  }
}
