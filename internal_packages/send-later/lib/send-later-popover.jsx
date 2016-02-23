/** @babel */
import _ from 'underscore'
import React, {Component, PropTypes} from 'react'
import {DateUtils} from 'nylas-exports'
import {Popover} from 'nylas-component-kit'
import SendLaterActions from './send-later-actions'
import SendLaterStore from './send-later-store'
import {DATE_FORMAT_SHORT, DATE_FORMAT_LONG} from './send-later-constants'


const SendLaterOptions = {
  'In 1 hour': DateUtils.in1Hour,
  'Later Today': DateUtils.laterToday,
  'Tomorrow Morning': DateUtils.tomorrow,
  'Tomorrow Evening': DateUtils.tomorrowEvening,
  'This Weekend': DateUtils.thisWeekend,
  'Next Week': DateUtils.nextWeek,
}

class SendLaterPopover extends Component {
  static displayName = 'SendLaterPopover';

  static propTypes = {
    draftClientId: PropTypes.string,
  };

  constructor(props) {
    super(props)
    this.state = {
      inputSendDate: null,
      isScheduled: SendLaterStore.isScheduled(this.props.draftClientId),
    }
  }

  componentDidMount() {
    this.unsubscribe = SendLaterStore.listen(this.onScheduledMessagesChanged)
  }

  componentWillUnmount() {
    this.unsubscribe()
  }

  onSendLater = (momentDate)=> {
    const utcDate = momentDate.utc()
    const formatted = DateUtils.format(utcDate)
    SendLaterActions.sendLater(this.props.draftClientId, formatted)

    this.setState({isScheduled: null, inputSendDate: null})
    this.refs.popover.close()
  };

  onCancelSendLater = ()=> {
    SendLaterActions.cancelSendLater(this.props.draftClientId)
    this.setState({inputSendDate: null})
    this.refs.popover.close()
  };

  onScheduledMessagesChanged = ()=> {
    const isScheduled = SendLaterStore.isScheduled(this.props.draftClientId)
    if (isScheduled !== this.state.isScheduled) {
      this.setState({isScheduled});
    }
  };

  onInputChange = (event)=> {
    this.updateInputSendDateValue(event.target.value)
  };

  getButtonLabel = (isScheduled)=> {
    return isScheduled ? '✅  Scheduled' : 'Send Later';
  };

  updateInputSendDateValue = _.debounce((dateValue)=> {
    const inputSendDate = DateUtils.fromString(dateValue)
    this.setState({inputSendDate})
  }, 250);

  renderItems() {
    return Object.keys(SendLaterOptions).map((label)=> {
      const date = SendLaterOptions[label]()
      const formatted = DateUtils.format(date, DATE_FORMAT_SHORT)
      return (
        <div
          key={label}
          onMouseDown={this.onSendLater.bind(this, date)}
          className="send-later-option">
          {label}
          <em className="item-date-value">{formatted}</em>
        </div>
      );
    })
  }

  renderEmptyInput() {
    return (
      <div className="send-later-section">
        <label>At a specific time</label>
        <input
          type="text"
          placeholder="e.g. Next Monday at 1pm"
          onChange={this.onInputChange}/>
      </div>
    )
  }

  renderLabeledInput(inputSendDate) {
    const formatted = DateUtils.format(inputSendDate, DATE_FORMAT_LONG)
    return (
      <div className="send-later-section">
        <label>At a specific time</label>
        <input
          type="text"
          placeholder="e.g. Next Monday at 1pm"
          onChange={this.onInputChange}/>
        <em className="input-date-value">{formatted}</em>
        <button
          className="btn btn-send-later"
          onClick={this.onSendLater.bind(this, inputSendDate)}>Schedule Email</button>
      </div>
    )
  }

  render() {
    const {isScheduled, inputSendDate} = this.state
    const buttonLabel = isScheduled != null ? this.getButtonLabel(isScheduled) : 'Scheduling...';
    const button = (
      <button className="btn btn-primary send-later-button">{buttonLabel}</button>
    )
    const input = inputSendDate ? this.renderLabeledInput(inputSendDate) : this.renderEmptyInput();

    return (
      <Popover
        ref="popover"
        style={{order: -103}}
        className="send-later"
        buttonComponent={button}>
        <div className="send-later-container">
          {this.renderItems()}
          <div className="divider" />
          {input}
          {isScheduled ?
            <div className="divider" />
          : void 0}
          {isScheduled ?
            <div className="send-later-section">
              <button className="btn btn-send-later" onClick={this.onCancelSendLater}>
                Unschedule Send
              </button>
            </div>
          : void 0}
        </div>
      </Popover>
    );
  }

}

export default SendLaterPopover
