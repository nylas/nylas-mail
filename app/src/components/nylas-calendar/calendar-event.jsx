import { React, ReactDOM, PropTypes, Event } from 'mailspring-exports';
import { InjectedComponentSet } from 'mailspring-component-kit';
import { calcColor } from './calendar-helpers';

export default class CalendarEvent extends React.Component {
  static displayName = 'CalendarEvent';

  static propTypes = {
    event: PropTypes.instanceOf(Event).isRequired,
    order: PropTypes.number,
    selected: PropTypes.bool,
    scopeEnd: PropTypes.number.isRequired,
    scopeStart: PropTypes.number.isRequired,
    direction: PropTypes.oneOf(['horizontal', 'vertical']),
    fixedSize: PropTypes.number,
    focused: PropTypes.bool,
    concurrentEvents: PropTypes.number,
    onClick: PropTypes.func,
    onDoubleClick: PropTypes.func,
    onFocused: PropTypes.func,
  };

  static defaultProps = {
    order: 1,
    direction: 'vertical',
    fixedSize: -1,
    concurrentEvents: 1,
    onClick: () => {},
    onDoubleClick: () => {},
    onFocused: () => {},
  };

  componentDidMount() {
    this._scrollFocusedEventIntoView();
  }

  componentDidUpdate() {
    this._scrollFocusedEventIntoView();
  }

  _scrollFocusedEventIntoView() {
    const { focused } = this.props;
    if (!focused) {
      return;
    }
    const eventNode = ReactDOM.findDOMNode(this);
    if (!eventNode) {
      return;
    }
    const { event, onFocused } = this.props;
    eventNode.scrollIntoViewIfNeeded(true);
    onFocused(event);
  }

  _getDimensions() {
    const scopeLen = this.props.scopeEnd - this.props.scopeStart;
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
      width = this.props.fixedSize;
      left = this.props.fixedSize * (this.props.order - 1);
    }

    top = `${top * 100}%`;
    height = `${height * 100}%`;

    return { left, width, height, top };
  }

  _getStyles() {
    let styles = {};
    if (this.props.direction === 'vertical') {
      styles = this._getDimensions();
    } else if (this.props.direction === 'horizontal') {
      const d = this._getDimensions();
      styles = {
        left: d.top,
        width: d.height,
        height: d.width,
        top: d.left,
      };
    }
    styles.backgroundColor = calcColor(this.props.event.calendarId);
    return styles;
  }

  _overflowBefore() {
    return Math.max(this.props.scopeStart - this.props.event.start, 0);
  }

  render() {
    const { direction, event, onClick, onDoubleClick, selected } = this.props;

    return (
      <div
        id={event.id}
        tabIndex={0}
        style={this._getStyles()}
        className={`calendar-event ${direction} ${selected ? 'selected' : null}`}
        onClick={e => onClick(e, event)}
        onDoubleClick={() => onDoubleClick(event)}
      >
        <span className="default-header" style={{ order: 0 }}>
          {event.displayTitle()}
        </span>
        <InjectedComponentSet
          className="event-injected-components"
          style={{ position: 'absolute' }}
          matching={{ role: 'Calendar:Event' }}
          exposedProps={{ event: event }}
          direction="row"
        />
      </div>
    );
  }
}
