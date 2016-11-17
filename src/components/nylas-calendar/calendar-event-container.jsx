import moment from 'moment'
import React from 'react'
import ReactDOM from 'react-dom'
import {Actions, DatabaseStore, Event, SyncbackEventTask} from 'nylas-exports'

export default class CalendarEventContainer extends React.Component {
  static displayName = "CalendarEventContainer";

  static propTypes = {
    onCalendarMouseUp: React.PropTypes.func,
    onCalendarMouseDown: React.PropTypes.func,
    onCalendarMouseMove: React.PropTypes.func,
  }

  constructor() {
    super()
    this._DOMCache = {}
  }

  componentDidMount() {
    window.addEventListener("mouseup", this._onWindowMouseUp)
  }

  componentWillUnmount() {
    window.removeEventListener("mouseup", this._onWindowMouseUp)
  }

  _onCalendarMouseUp = (event) => {
    this._DOMCache = {};
    if (!this._mouseIsDown) {
      return
    }
    const data = this._dataFromMouseEvent(event);

    // An event was dragged, persist and syncback the updated times
    if (this._mouseDownCalEventId && data.time) {
      const origTime = this._mouseDownTime; // Store current value for use in callback

      DatabaseStore.find(Event, this._mouseDownCalEventId).then((calEvent) => {
        const newCalEvent = calEvent.shiftTimes(this._dragHandles, origTime, data.time);

        DatabaseStore.inTransaction((t) => {
          t.persistModel(newCalEvent);
        }).then(() => {
          const task = new SyncbackEventTask(newCalEvent.clientId);
          Actions.queueTask(task);
        })
      })
    }

    this._mouseIsDown = false;
    this._mouseDownTime = null;
    this._mouseDownCalEventId = null;
    this._runPropsHandler("onCalendarMouseUp", event, data)
  }

  _onCalendarMouseDown = (event) => {
    this._DOMCache = {};
    this._mouseIsDown = true;

    // Note that the values of _dragHandles are used to figure out which time fields
    // in the Event model should be updated. Only 'start' and 'end' are valid values.
    this._dragHandles = [];

    const data = this._dataFromMouseEvent(event);
    this._mouseDownTime = data.time;

    if (data.calEventId) {
      this._mouseDownCalEventId = data.calEventId;

      const classList = event.target.classList;
      if (classList.contains("top")) {
        this._dragHandles.push("start");
      } else if (classList.contains("bottom")) {
        this._dragHandles.push("end");
      } else {
        this._dragHandles.push("start", "end");
      }
    }

    this._runPropsHandler("onCalendarMouseDown", event, data)
  }

  _onCalendarMouseMove = (event) => {
    this._runPropsHandler("onCalendarMouseMove", event)
  }


  // data is an optional param for if the handler already ran
  // this._dataFromMouseEvent() and can pass those results in. If not,
  // this._dataFromMouseEvent() will be run here in this function.
  _runPropsHandler(name, event, data) {
    const propsFn = this.props[name]
    if (!propsFn) { return }
    const {time, x, y, width, height, calEventId} = data || this._dataFromMouseEvent(event);
    try {
      const args = {event, time, x, y, width, height, calEventId};
      args.mouseIsDown = this._mouseIsDown;
      args.mouseDownTime = this._mouseDownTime;
      args.mouseDownCalEventId = this._mouseDownCalEventId;
      args.dragHandles = this._dragHandles;
      propsFn(args);
    } catch (error) {
      NylasEnv.reportError(error)
    }
  }

  _dataFromMouseEvent(event) {
    let x = null;
    let y = null;
    let width = null;
    let height = null;
    let time = null;
    if (!event.target || !event.target.closest) { return {x, y, width, height, time} }
    const eventColumn = event.target.closest(".event-column");
    const gridWrap = this._DOMCache.gridWrap || event.target.closest(".event-grid-wrap .scroll-region-content-inner");
    const calWrap = this._DOMCache.calWrap || event.target.closest(".calendar-area-wrap")
    if (!gridWrap || !eventColumn) { return {x, y, width, height, time} }

    const rect = this._DOMCache.rect || gridWrap.getBoundingClientRect();
    const calWrapRect = this._DOMCache.calWrapRect || calWrap.getBoundingClientRect();

    this._DOMCache = {rect, gridWrap, calWrap}

    y = (gridWrap.scrollTop + event.clientY - rect.top);
    x = (calWrap.scrollLeft + event.clientX - calWrapRect.left);
    width = gridWrap.scrollWidth;
    height = gridWrap.scrollHeight;
    const percentDay = y / height;
    const diff = ((+eventColumn.dataset.end) - (+eventColumn.dataset.start))
    time = moment(diff * percentDay + (+eventColumn.dataset.start));

    let calEventId;
    const closestCalEvent = event.target.closest(".calendar-event");
    if (closestCalEvent) {
      calEventId = closestCalEvent.dataset.id;
    }

    return {x, y, width, height, time, calEventId}
  }

  _onWindowMouseUp = (event) => {
    if (ReactDOM.findDOMNode(this).contains(event.target)) {
      return
    }
    this._onCalendarMouseUp(event)
  }

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
    )
  }
}
