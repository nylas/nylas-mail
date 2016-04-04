import React from 'react'
import {Event, Utils} from 'nylas-exports'
import {InjectedComponentSet} from 'nylas-component-kit'

export default class CalendarEvent extends React.Component {
  static displayName = "CalendarEvent";

  static propTypes = {
    event: React.PropTypes.instanceOf(Event).isRequired,
    order: React.PropTypes.number,
    scopeEnd: React.PropTypes.number.isRequired,
    scopeStart: React.PropTypes.number.isRequired,
    direction: React.PropTypes.oneOf(['horizontal', 'vertical']),
    fixedSize: React.PropTypes.number,
    concurrentEvents: React.PropTypes.number,
  }

  static defaultProps = {
    order: 1,
    direction: "vertical",
    fixedSize: -1,
    concurrentEvents: 1,
  }

  _styles() {
    let styles = {}

    if (this.props.direction === "vertical") {
      styles = this._dimensions()
    } else if (this.props.direction === "horizontal") {
      const d = this._dimensions()
      styles = {
        left: d.top,
        width: d.height,
        height: d.width,
        top: d.left,
      }
    }

    styles.backgroundColor = this._bgColor();

    return styles
  }

  _dimensions() {
    const scopeLen = this.props.scopeEnd - this.props.scopeStart
    const duration = this.props.event.end - this.props.event.start;

    let top = Math.max((this.props.event.start - this.props.scopeStart) / scopeLen, 0);
    let height = Math.min((duration - this._overflowBefore()) / scopeLen, 1);

    let width = 1;
    let left;
    if (this.props.fixedSize === -1) {
      width = 1 / this.props.concurrentEvents;
      left = width * (this.props.order - 1);
      width = `${width * 100}%`;
      left = `${left * 100}%`;
    } else {
      width = this.props.fixedSize
      left = this.props.fixedSize * (this.props.order - 1);
    }

    top = `${top * 100}%`
    height = `${height * 100}%`

    return {left, width, height, top}
  }

  _bgColor() {
    let bgColor = NylasEnv.config.get(`calendar.colors.${this.props.event.calendarId}`)
    if (!bgColor) {
      const hue = Utils.hueForString(this.props.event.calendarId);
      bgColor = `hsla(${hue}, 50%, 45%, 0.35)`
    }
    return bgColor
  }

  _overflowBefore() {
    return Math.max(this.props.scopeStart - this.props.event.start, 0)
  }

  render() {
    return (
      <div className={`calendar-event ${this.props.direction}`}
        style={this._styles()}
      >
        <span className="default-header" style={{order: 0}}>
          {this.props.event.title}
        </span>
        <InjectedComponentSet
          matching={{role: "Calendar:Event"}}
          exposedProps={{event: this.props.event}}
          direction="row"
        />
      </div>
    )
  }
}
