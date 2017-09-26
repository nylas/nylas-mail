import moment from 'moment';

import React from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';

export default class CalendarEventContainer extends React.Component {
  static displayName = 'CalendarEventContainer';

  static propTypes = {
    onCalendarMouseUp: PropTypes.func,
    onCalendarMouseDown: PropTypes.func,
    onCalendarMouseMove: PropTypes.func,
  };

  constructor() {
    super();
    this._DOMCache = {};
  }

  componentDidMount() {
    window.addEventListener('mouseup', this._onWindowMouseUp);
  }

  componentWillUnmount() {
    window.removeEventListener('mouseup', this._onWindowMouseUp);
  }

  _onCalendarMouseUp = event => {
    this._DOMCache = {};
    if (!this._mouseIsDown) {
      return;
    }
    this._mouseIsDown = false;
    this._runPropsHandler('onCalendarMouseUp', event);
  };

  _onCalendarMouseDown = event => {
    this._DOMCache = {};
    this._mouseIsDown = true;
    this._runPropsHandler('onCalendarMouseDown', event);
  };

  _onCalendarMouseMove = event => {
    this._runPropsHandler('onCalendarMouseMove', event);
  };

  _runPropsHandler(name, event) {
    const propsFn = this.props[name];
    if (!propsFn) {
      return;
    }
    const { time, x, y, width, height } = this._dataFromMouseEvent(event);
    try {
      propsFn({ event, time, x, y, width, height, mouseIsDown: this._mouseIsDown });
    } catch (error) {
      AppEnv.reportError(error);
    }
  }

  _dataFromMouseEvent(event) {
    let x = null;
    let y = null;
    let width = null;
    let height = null;
    let time = null;
    if (!event.target || !event.target.closest) {
      return { x, y, width, height, time };
    }
    const eventColumn = this._DOMCache.eventColumn || event.target.closest('.event-column');
    const gridWrap =
      this._DOMCache.gridWrap ||
      event.target.closest('.event-grid-wrap .scroll-region-content-inner');
    const calWrap = this._DOMCache.calWrap || event.target.closest('.calendar-area-wrap');
    if (!gridWrap || !eventColumn) {
      return { x, y, width, height, time };
    }

    const rect = this._DOMCache.rect || gridWrap.getBoundingClientRect();
    const calWrapRect = this._DOMCache.calWrapRect || calWrap.getBoundingClientRect();

    this._DOMCache = { rect, eventColumn, gridWrap, calWrap };

    y = gridWrap.scrollTop + event.clientY - rect.top;
    x = calWrap.scrollLeft + event.clientX - calWrapRect.left;
    width = gridWrap.scrollWidth;
    height = gridWrap.scrollHeight;
    const percentDay = y / height;
    const diff = +eventColumn.dataset.end - +eventColumn.dataset.start;
    time = moment(diff * percentDay + +eventColumn.dataset.start);
    return { x, y, width, height, time };
  }

  _onWindowMouseUp = event => {
    if (ReactDOM.findDOMNode(this).contains(event.target)) {
      return;
    }
    this._onCalendarMouseUp(event);
  };

  render() {
    return (
      <div
        className="calendar-mouse-handler"
        onMouseUp={this._onCalendarMouseUp}
        onMouseDown={this._onCalendarMouseDown}
        onMouseMove={this._onCalendarMouseMove}
      >
        {this.props.children}
      </div>
    );
  }
}
