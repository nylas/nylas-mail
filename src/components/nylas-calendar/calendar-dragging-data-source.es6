import Rx from 'rx-lite';
import {DatabaseStore, Event, Utils} from 'nylas-exports';
import CalendarDataSource from './calendar-data-source';

/* This is a modified version of the CalendarDataSource that incorporates mouse
events in order to allow us to render the dragging/resizing of an event across
an entire calendar view. It removes the targeted event from the results of the
CalendarDataSource and adds a clone of that event with the updated times. */

export default class CalendarDraggingDataSource extends CalendarDataSource {
  buildObservable({startTime, endTime, disabledCalendars, mouseHandlerObserver}) {
    this.observable = Rx.Observable.combineLatest(
      super.buildObservable({startTime, endTime, disabledCalendars}),
      mouseHandlerObserver,
    )
    .flatMapLatest(([superResult, mouseEventData]) => {
      const results = Utils.deepClone(superResult);
      const {calEventId, mouseDownCalEventId} = mouseEventData;

      // Dragging
      if (mouseDownCalEventId != null) {
        const {event} = this._findEvent(results.events, mouseDownCalEventId, true);

        // If we don't have the dragged event, find it in the database
        if (!event) {
          return Rx.Observable.fromPromise(
            DatabaseStore.find(Event, mouseDownCalEventId).then((e) => {
              this._dragAndAddEvent(e, mouseEventData, results);
              return Promise.resolve(results);
            })
          )
        }

        this._dragAndAddEvent(event, mouseEventData, results);
      }

      // Hovering
      if (calEventId != null && mouseDownCalEventId == null) {
        const {event, index} = this._findEvent(results.events, calEventId);
        if (event) {
          event.hovered = true;
          // Keep the events in order so that hovering over an overlapping event
          // doesn't make it change positions.
          results.events.splice(index, 1, event)
        }
      }
      return Rx.Observable.from([results]);
    })
    return this.observable;
  }

  subscribe(callback) {
    return this.observable.subscribe(callback)
  }

  /*
   * Create a dragged version of the event, based on the mouseData, and add it
   * to the results.
   *
   * event - the calendar event that should be dragged
   * mouseData - the data from the mouse event
   * allResults - the whole results object, should have an 'events' entry that
   *   stores an array of calendar event models
   */
  _dragAndAddEvent(event, mouseData, allResults) {
    let newEvent;
    if (mouseData.time) {
      newEvent = event.shiftTimes(mouseData.dragHandles, mouseData.mouseDownTime, mouseData.time);
    } else {
      newEvent = event.clone();
    }
    newEvent.hovered = true;
    newEvent.dragged = true;
    allResults.events.push(newEvent);
  }

  /*
   * Given an array of events and an eventId, find the event with that id.
   *
   * events - an array of calendar event models
   * eventId - the id of the desired event
   * remove - a boolean indicating whether event should be removed from the
   *   events array
   * Returns an object - {
   *   event: the matching event,
   *   index: the index of the event within the events array,
   * }
   */
  _findEvent(events, eventId, removeEvent) {
    let event;
    let i;
    for (i = 0; i < events.length; i++) {
      if (events[i].id === eventId) {
        event = events[i]
        if (removeEvent) {
          events.splice(i, 1);
        }
        break;
      }
    }
    return {event, index: i};
  }
}
