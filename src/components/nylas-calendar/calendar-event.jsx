import React from 'react'
import {Event} from 'nylas-exports'
import {InjectedComponentSet} from 'nylas-component-kit'
import {calcColor} from './calendar-helpers'

export default class CalendarEvent extends React.Component {
  static displayName = "CalendarEvent";

  static propTypes = {
    event: React.PropTypes.instanceOf(Event).isRequired,
    order: React.PropTypes.number,
    selected: React.PropTypes.bool,
    scopeEnd: React.PropTypes.number.isRequired,
    scopeStart: React.PropTypes.number.isRequired,
    direction: React.PropTypes.oneOf(['horizontal', 'vertical']),
    fixedSize: React.PropTypes.number,
    concurrentEvents: React.PropTypes.number,
    onClick: React.PropTypes.func,
    onDoubleClick: React.PropTypes.func,
  }

  static defaultProps = {
    order: 1,
    direction: "vertical",
    fixedSize: -1,
    concurrentEvents: 1,
    onClick: () => {},
    onDoubleClick: () => {},
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

    styles.backgroundColor = calcColor(this.props.event.calendarId);

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

  _overflowBefore() {
    return Math.max(this.props.scopeStart - this.props.event.start, 0)
  }

  render() {
    const {direction, event, onClick, onDoubleClick, selected} = this.props;

    return (
      <div
        tabIndex={0}
        className={`calendar-event ${direction} ${selected ? 'selected' : null}`}
        onClick={(e) => onClick(e, event)}
        onDoubleClick={(e) => onDoubleClick(e, event)}
        style={this._styles()}
      >
        <span className="default-header" style={{order: 0}}>
          {event.title}
        </span>
        <InjectedComponentSet
          className="event-injected-components"
          style={{position: "absolute"}}
          matching={{role: "Calendar:Event"}}
          exposedProps={{event: event}}
          direction="row"
        />
      </div>
    )
  }
}
