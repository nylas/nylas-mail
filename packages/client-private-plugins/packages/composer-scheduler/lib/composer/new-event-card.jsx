import React from 'react';
import moment from 'moment-timezone'
import {
  RetinaImg,
  DatePicker,
  TimePicker,
  TabGroupRegion,
} from 'nylas-component-kit'

import {
  DateUtils,
  Calendar,
  AccountStore,
  DatabaseStore} from 'nylas-exports';

import {PLUGIN_ID} from '../scheduler-constants'
import NewEventHelper from './new-event-helper'
import ProposedTimeList from './proposed-time-list'

export default class NewEventCard extends React.Component {
  static displayName = 'NewEventCard';

  static propTypes = {
    event: React.PropTypes.object.isRequired,
    draft: React.PropTypes.object.isRequired,
    onChange: React.PropTypes.func.isRequired,
    onRemove: React.PropTypes.func.isRequired,
    onParticipantsClick: React.PropTypes.func.isRequired,
  };

  constructor(props) {
    super(props);
    this._mounted = false;
    this.state = {
      calendars: [],
    };
  }

  componentDidMount() {
    this._mounted = true;
    const email = this.props.draft.from[0].email
    this._loadCalendarsForEmail(email);
  }

  componentWillReceiveProps(newProps) {
    const email = newProps.draft.from[0].email
    this._loadCalendarsForEmail(email);
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  _loadCalendarsForEmail(email) {
    if (this._lastEmail === email) {
      return
    }
    this._lastEmail = email

    const account = AccountStore.accountForEmail(email);
    DatabaseStore.findAll(Calendar, {accountId: account.id})
    .then((calendars) => {
      if (!this._mounted || !calendars) { return }
      this.setState({calendars: calendars.filter(c => !c.readOnly)})
    });
  }

  _renderIcon(name) {
    return (<span className="field-icon">
      <RetinaImg name={name} mode={RetinaImg.Mode.ContentPreserve} />
    </span>)
  }

  _renderParticipants() {
    return this.props.draft.participants().map(r => r.displayName()).join(", ")
  }

  _renderCalendarPicker() {
    if (this.state.calendars.length <= 1) {
      return false;
    }
    const calOpts = this.state.calendars.map(cal =>
      <option key={cal.serverId} value={cal.serverId}>{cal.name}</option>
    );
    const onChange = (e) => { this.props.onChange({calendarId: e.target.value}) }
    return (
      <div className="row calendar">
        {this._renderIcon("ic-eventcard-calendar@2x.png")}
        <select onChange={onChange}>{calOpts}</select>
      </div>
    )
  }

  _onProposeTimes = () => {
    NewEventHelper.launchCalendarWindow(this.props.draft.clientId);
  }

  _eventStart() {
    return moment.unix(this.props.event.start || moment().unix())
  }

  _eventEnd() {
    return moment.unix(this.props.event.end || moment().unix())
  }

  _onChangeDay = (newTimestamp) => {
    const newDay = moment(newTimestamp)
    const start = this._eventStart()
    const end = this._eventEnd()
    start.year(newDay.year())
    end.year(newDay.year())
    start.dayOfYear(newDay.dayOfYear())
    end.dayOfYear(newDay.dayOfYear())
    this.props.onChange({start: start.unix(), end: end.unix()})
  }

  _onChangeStartTime = (newTimestamp) => {
    const newTime = moment(newTimestamp)
    const start = this._eventStart()
    const end = this._eventEnd()
    start.hour(newTime.hour())
    start.minute(newTime.minute())
    let newEnd = moment(end)
    if (end.isSameOrBefore(start)) {
      const leftInDay = moment(start).endOf('day').diff(start)
      const move = Math.min(leftInDay, moment.duration(1, 'hour').asMilliseconds());
      newEnd = moment(start).add(move, 'ms')
    }
    this.props.onChange({start: start.unix(), end: newEnd.unix()})
  }

  _onChangeEndTime = (newTimestamp) => {
    const newTime = moment(newTimestamp)
    const start = this._eventStart()
    const end = this._eventEnd()
    end.hour(newTime.hour())
    end.minute(newTime.minute())
    let newStart = moment(start)
    if (start.isSameOrAfter(end)) {
      const sinceDay = end.diff(moment(end).startOf('day'))
      const move = Math.min(sinceDay, moment.duration(1, 'hour').asMilliseconds());
      newStart = moment(end).subtract(move, 'ms');
    }
    this.props.onChange({end: end.unix(), start: newStart.unix()})
  }

  _renderTimePicker() {
    const metadata = this.props.draft.metadataForPluginId(PLUGIN_ID);
    if (metadata && metadata.proposals) {
      return (
        <ProposedTimeList
          event={this.props.event}
          draft={this.props.draft}
          proposals={metadata.proposals}
        />
      )
    }

    const startVal = (this.props.event.start) * 1000;
    const endVal = (this.props.event.end) * 1000;
    return (
      <div className="row time">
        {this._renderIcon("ic-eventcard-time@2x.png")}
        <span>
          <TimePicker
            value={startVal}
            onChange={this._onChangeStartTime}
          />
          to
          <TimePicker
            value={endVal}
            relativeTo={startVal}
            onChange={this._onChangeEndTime}
          />
          <span className="timezone">
            {moment().tz(DateUtils.timeZone).format("z")}
          </span>
          &nbsp;
          on
          &nbsp;
          <DatePicker value={startVal} onChange={this._onChangeDay} />
        </span>
      </div>
    )
  }

  _renderSuggestPrompt() {
    const metadata = this.props.draft.metadataForPluginId(PLUGIN_ID);
    if (metadata && metadata.proposals) {
      return (
        <div className="suggest-times">
          <a onClick={this._onProposeTimes}>Select different times…</a>
        </div>
      )
    }
    return (
      <div className="suggest-times">
        or: <a onClick={this._onProposeTimes}>Suggest several times…</a>
      </div>
    )
  }

  render() {
    return (
      <div className="new-event-card">
        <TabGroupRegion>
          <div className="remove-button" onClick={this.props.onRemove}>✕</div>
          <div className="row title">
            {this._renderIcon("ic-eventcard-description@2x.png")}
            <input
              type="text"
              name="title"
              className="event-title"
              placeholder="Add an event title"
              value={this.props.event.title || ""}
              onChange={e => this.props.onChange({title: e.target.value})}
            />
          </div>

          {this._renderTimePicker()}

          {this._renderSuggestPrompt()}

          {this._renderCalendarPicker()}

          <div className="row recipients">
            {this._renderIcon("ic-eventcard-people@2x.png")}
            <div onClick={this.props.onParticipantsClick()}>{this._renderParticipants()}</div>
          </div>

          <div className="row location">
            {this._renderIcon("ic-eventcard-location@2x.png")}
            <input
              type="text"
              name="location"
              placeholder="Add a location"
              value={this.props.event.location}
              onChange={e => this.props.onChange({location: e.target.value})}
            />
          </div>

          <div className="row description">
            {this._renderIcon("ic-eventcard-notes@2x.png")}

            <textarea
              ref="description"
              name="description"
              placeholder="Add notes"
              value={this.props.event.description}
              onChange={e => this.props.onChange({description: e.target.value})}
            />
          </div>
        </TabGroupRegion>
      </div>
    )
  }
}
