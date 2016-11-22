import React from 'react';
import {
  Actions,
  Calendar,
  DatabaseStore,
  DateUtils,
  Event,
  SyncbackEventTask,
} from 'nylas-exports'

export default class QuickEventPopover extends React.Component {

  constructor(props) {
    super(props)
    this.state = {
      start: null,
      end: null,
      leftoverText: null,
    }
  }

  onInputKeyDown = (event) => {
    const {key, target: {value}} = event;
    if (value.length > 0 && ["Enter", "Return"].includes(key)) {
      // This prevents onInputChange from being fired
      event.stopPropagation();
      this.createEvent(DateUtils.parseDateString(value));
      Actions.closePopover();
    }
  };

  onInputChange = (event) => {
    this.setState(DateUtils.parseDateString(event.target.value));
  };

  createEvent = ({leftoverText, start, end}) => {
    DatabaseStore.findAll(Calendar).then((allCalendars) => {
      if (allCalendars.length === 0) {
        throw new Error("Can't create an event, you have no calendars");
      }
      const cals = allCalendars.filter(c => !c.readOnly);
      if (cals.length === 0) {
        NylasEnv.showErrorDialog("This account has no editable calendars. We can't " +
          "create an event for you. Please make sure you have an editable calendar " +
          "with your account provider.");
        return Promise.reject();
      }

      const event = new Event({
        calendarId: cals[0].id,
        accountId: cals[0].accountId,
        start: start.unix(),
        end: end.unix(),
        when: {
          start_time: start.unix(),
          end_time: end.unix(),
        },
        title: leftoverText,
      })

      return DatabaseStore.inTransaction((t) => {
        return t.persistModel(event)
      }).then(() => {
        const task = new SyncbackEventTask(event.clientId);
        Actions.queueTask(task);
      })
    })
  }


  render() {
    let dateInterpretation;
    if (this.state.start) {
      dateInterpretation = (
        <span className="date-interpretation">
          Title: {this.state.leftoverText} <br />
          Start: {DateUtils.format(this.state.start, DateUtils.DATE_FORMAT_SHORT)} <br />
          End: {DateUtils.format(this.state.end, DateUtils.DATE_FORMAT_SHORT)}
        </span>
      );
    }

    return (
      <div className="quick-event-popover nylas-date-input">
        <input
          tabIndex="0"
          type="text"
          placeholder="Coffee next Monday at 9AM'"
          onKeyDown={this.onInputKeyDown}
          onChange={this.onInputChange}
        />
        {dateInterpretation}
      </div>
    )
  }
}
