import moment from 'moment';
import {
  React,
  PropTypes,
  Actions,
  DatabaseStore,
  DateUtils,
  SyncbackEventTask,
} from 'mailspring-exports';
import {
  DatePicker,
  RetinaImg,
  ScrollRegion,
  TabGroupRegion,
  TimePicker,
} from 'mailspring-component-kit';
import EventParticipantsInput from './event-participants-input';

export default class CalendarEventPopover extends React.Component {
  static propTypes = {
    event: PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);
    const { description, start, end, location, participants } = this.props.event;

    this.state = { description, start, end, location };
    this.state.title = this.props.event.displayTitle();
    this.state.editing = false;
    this.state.participants = participants || [];
  }

  componentWillReceiveProps = nextProps => {
    const { description, start, end, location, participants } = nextProps.event;
    this.setState({ description, start, end, location });
    this.setState({
      participants: participants || [],
      title: nextProps.event.displayTitle(),
    });
  };

  onEdit = () => {
    this.setState({ editing: true });
  };

  getStartMoment = () => moment(this.state.start * 1000);
  getEndMoment = () => moment(this.state.end * 1000);

  saveEdits = () => {
    const event = this.props.event.clone();
    const keys = ['title', 'description', 'location', 'participants'];
    for (const key of keys) {
      event[key] = this.state[key];
    }

    // TODO, this component shouldn't save the event here, we should expose an
    // `onEditEvent` or similar callback
    // TODO: How will this affect the event if the when object was originally
    //   a datespan, with start_date and end_date attributes?
    event.when.start_time = this.state.start;
    event.when.end_time = this.state.end;

    DatabaseStore.inTransaction(t => {
      this.setState({ editing: false }); // TODO: where's the best place to put this?
      return t.persistModel(event);
    }).then(() => {
      const task = new SyncbackEventTask(event.id);
      Actions.queueTask(task);
    });
  };

  extractNotesFromDescription(node) {
    const els = node.querySelectorAll('meta[itemprop=description]');
    let notes = null;
    if (els.length) {
      notes = Array.from(els)
        .map(el => el.content)
        .join('\n');
    } else {
      notes = node.innerText;
    }
    while (true) {
      const nextNotes = notes.replace('\n\n', '\n');
      if (nextNotes === notes) {
        break;
      }
      notes = nextNotes;
    }
    return notes;
  }

  // If on the hour, formats as "3 PM", else formats as "3:15 PM"
  formatTime(momentTime) {
    const min = momentTime.minutes();
    if (min === 0) {
      return momentTime.format('h A');
    }
    return momentTime.format('h:mm A');
  }

  updateParticipants = participants => {
    this.setState({ participants });
  };

  updateField = (key, value) => {
    const updates = {};
    updates[key] = value;
    this.setState(updates);
  };

  _onChangeDay = newTimestamp => {
    const newDay = moment(newTimestamp);
    const start = this.getStartMoment();
    const end = this.getEndMoment();
    start.year(newDay.year());
    end.year(newDay.year());
    start.dayOfYear(newDay.dayOfYear());
    end.dayOfYear(newDay.dayOfYear());
    this.setState({ start: start.unix(), end: end.unix() });
  };

  _onChangeStartTime = newTimestamp => {
    const newStart = moment(newTimestamp);
    let newEnd = this.getEndMoment();
    if (newEnd.isSameOrBefore(newStart)) {
      const leftInDay = moment(newStart)
        .endOf('day')
        .diff(newStart);
      const move = Math.min(leftInDay, moment.duration(1, 'hour').asMilliseconds());
      newEnd = moment(newStart).add(move, 'ms');
    }
    this.setState({ start: newStart.unix(), end: newEnd.unix() });
  };

  _onChangeEndTime = newTimestamp => {
    const newEnd = moment(newTimestamp);
    let newStart = this.getStartMoment();
    if (newStart.isSameOrAfter(newEnd)) {
      const sinceDay = moment(newEnd).diff(newEnd.startOf('day'));
      const move = Math.min(sinceDay, moment.duration(1, 'hour').asMilliseconds());
      newStart = moment(newEnd).subtract(move, 'ms');
    }
    this.setState({ end: newEnd.unix(), start: newStart.unix() });
  };

  renderTime() {
    const startMoment = this.getStartMoment();
    const endMoment = this.getEndMoment();
    const date = startMoment.format('dddd, MMMM D'); // e.g. Tuesday, February 22
    const timeRange = `${this.formatTime(startMoment)} - ${this.formatTime(endMoment)}`;
    return (
      <div>
        {date}
        <br />
        {timeRange}
      </div>
    );
  }

  renderEditableTime() {
    const startVal = this.state.start * 1000;
    const endVal = this.state.end * 1000;
    return (
      <div className="row time">
        <RetinaImg name="ic-eventcard-time@2x.png" mode={RetinaImg.Mode.ContentPreserve} />
        <span>
          <TimePicker value={startVal} onChange={this._onChangeStartTime} />
          to
          <TimePicker value={endVal} onChange={this._onChangeEndTime} />
          <span className="timezone">
            {moment()
              .tz(DateUtils.timeZone)
              .format('z')}
          </span>
          &nbsp; on &nbsp;
          <DatePicker value={startVal} onChange={this._onChangeDay} />
        </span>
      </div>
    );
  }

  renderParticipants(participants) {
    const names = [];
    for (let i = 0; i < participants.length; i++) {
      names.push(<div key={i}> {participants[i].name} </div>);
    }
    return names;
  }

  renderEditable = () => {
    const { title, description, start, end, location, participants } = this.state;

    const fragment = document.createDocumentFragment();
    const descriptionRoot = document.createElement('root');
    fragment.appendChild(descriptionRoot);
    descriptionRoot.innerHTML = description;

    const notes = this.extractNotesFromDescription(descriptionRoot);

    return (
      <div className="calendar-event-popover" tabIndex="0">
        <TabGroupRegion>
          <div className="title-wrapper">
            <input
              className="title"
              type="text"
              value={title}
              onChange={e => {
                this.updateField('title', e.target.value);
              }}
            />
          </div>
          <input
            className="location"
            type="text"
            value={location}
            onChange={e => {
              this.updateField('location', e.target.value);
            }}
          />
          <div className="section">{this.renderEditableTime(start, end)}</div>
          <div className="section">
            <div className="label">Invitees: </div>
            <EventParticipantsInput
              className="event-participant-field"
              participants={participants}
              change={val => {
                this.updateField('participants', val);
              }}
            />
          </div>
          <div className="section">
            <div className="label">Notes: </div>
            <input
              type="text"
              value={notes}
              onChange={e => {
                this.updateField('description', e.target.value);
              }}
            />
          </div>
          <span onClick={this.saveEdits}>Save</span>
          <span onClick={() => Actions.closePopover()}>Cancel</span>
        </TabGroupRegion>
      </div>
    );
  };

  render() {
    if (this.state.editing) {
      return this.renderEditable();
    }
    const { title, description, location, participants } = this.state;

    const fragment = document.createDocumentFragment();
    const descriptionRoot = document.createElement('root');
    fragment.appendChild(descriptionRoot);
    descriptionRoot.innerHTML = description;

    const notes = this.extractNotesFromDescription(descriptionRoot);

    return (
      <div className="calendar-event-popover" tabIndex="0">
        <div className="title-wrapper">
          <div className="title">{title}</div>
          <RetinaImg
            className="edit-icon"
            name="edit-icon.png"
            title="Edit Item"
            mode={RetinaImg.Mode.ContentIsMask}
            onClick={this.onEdit}
          />
        </div>
        <div className="location">{location}</div>
        <div className="section">{this.renderTime()}</div>
        <div className="section">
          <div className="label">Invitees: </div>
          {this.renderParticipants(participants)}
        </div>
        <div className="section">
          <div className="description">
            <div className="label">Notes: </div>
            <ScrollRegion>
              <div>{notes}</div>
            </ScrollRegion>
          </div>
        </div>
      </div>
    );
  }
}
