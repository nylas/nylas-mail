import {
  Actions,
  DestroyModelTask,
  CalendarDataSource,
} from 'nylas-exports';

import {
  KeyCommandsRegion,
  NylasCalendar,
} from 'nylas-component-kit';
import React from 'react';
import ReactDOM from 'react-dom';
import {remote} from 'electron';

import CalendarEventPopover from './calendar-event-popover';

export default class CalendarWrapper extends React.Component {
  static displayName = 'CalendarWrapper';
  static containerRequired = false;

  constructor(props) {
    super(props);
    this._dataSource = new CalendarDataSource();
    this.state = {selectedEvents: []};
  }

  _onEventClick = (e, event) => {
    let next = [].concat(this.state.selectedEvents);

    if (e.shiftKey || e.metaKey) {
      const idx = next.findIndex(({id}) => event.id === id)
      if (idx === -1) {
        next.push(event)
      } else {
        next.splice(idx, 1)
      }
    } else {
      next = [event];
    }

    this.setState({
      selectedEvents: next,
    });
  }

  _onEventDoubleClick = (e, event) => {
    const eventEl = e.target.closest('.calendar-event');
    const eventRect = ReactDOM.findDOMNode(eventEl).getBoundingClientRect()

    Actions.openPopover(
      <CalendarEventPopover event={event} />
    , {
      originRect: eventRect,
      direction: 'right',
      fallbackDirection: 'left',
    })
  }

  _onDeleteSelectedEvents = () => {
    if (this.state.selectedEvents.length === 0) {
      return;
    }
    const response = remote.dialog.showMessageBox(remote.getCurrentWindow(), {
      type: 'warning',
      buttons: ['Delete', 'Cancel'],
      message: 'Delete or decline these events?',
      detail: `Are you sure you want to delete or decline invitations for the selected event(s)?`,
    });
    if (response === 0) { // response is button array index
      for (const event of this.state.selectedEvents) {
        const task = new DestroyModelTask({
          clientId: event.clientId,
          modelName: event.constructor.name,
          endpoint: '/events',
          accountId: event.accountId,
        })
        Actions.queueTask(task);
      }
    }
  }

  render() {
    return (
      <KeyCommandsRegion
        className="main-calendar"
        localHandlers={{
          'core:remove-from-view': this._onDeleteSelectedEvents,
        }}
      >
        <NylasCalendar
          dataSource={this._dataSource}
          onEventClick={this._onEventClick}
          onEventDoubleClick={this._onEventDoubleClick}
          selectedEvents={this.state.selectedEvents}
        />
      </KeyCommandsRegion>
    )
  }
}
