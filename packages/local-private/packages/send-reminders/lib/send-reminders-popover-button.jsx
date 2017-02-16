import React, {Component, PropTypes} from 'react';
import ReactDOM from 'react-dom';
import {Rx, Actions, Message, DatabaseStore} from 'nylas-exports';
import {RetinaImg, ListensToObservable} from 'nylas-component-kit';
import SendRemindersPopover from './send-reminders-popover';
import {getLatestMessage, setMessageReminder, reminderDateForMessage} from './send-reminders-utils'


function getMessageObservable({thread} = {}) {
  if (!thread) { return Rx.Observable.empty() }
  const latestMessage = getLatestMessage(thread) || {}
  const query = DatabaseStore.find(Message, latestMessage.id)
  return Rx.Observable.fromQuery(query)
}

function getStateFromObservable(message, {props}) {
  const {thread} = props
  if (!message) {
    return {latestMessage: getLatestMessage(thread)}
  }
  return {latestMessage: message}
}


class SendRemindersPopoverButton extends Component {
  static displayName = 'SendRemindersPopoverButton';

  static propTypes = {
    className: PropTypes.string,
    thread: PropTypes.object,
    latestMessage: PropTypes.object,
    direction: PropTypes.string,
    getBoundingClientRect: PropTypes.func,
  };

  static defaultProps = {
    className: 'btn btn-toolbar',
    direction: 'down',
    getBoundingClientRect: (inst) => ReactDOM.findDOMNode(inst).getBoundingClientRect(),
  };

  onSetReminder = (reminderDate, dateLabel) => {
    const {latestMessage} = this.props
    setMessageReminder(latestMessage.accountId, latestMessage, reminderDate, dateLabel)
  }

  onClick = (event) => {
    event.stopPropagation()
    const {direction, latestMessage, getBoundingClientRect} = this.props
    const reminderDate = reminderDateForMessage(latestMessage)
    const buttonRect = getBoundingClientRect(this)
    Actions.openPopover(
      <SendRemindersPopover
        reminderDate={reminderDate}
        onRemind={this.onSetReminder}
        onCancelReminder={() => this.onSetReminder(null)}
      />,
      {originRect: buttonRect, direction}
    )
  };

  render() {
    const {className, latestMessage} = this.props
    const reminderDate = reminderDateForMessage(latestMessage)
    const title = reminderDate ? 'Edit reminder' : 'Set reminder';
    return (
      <button
        title={title}
        tabIndex={-1}
        className={`send-reminders-toolbar-button ${className}`}
        onClick={this.onClick}
      >
        <RetinaImg
          name="ic-toolbar-native-reminder.png"
          mode={RetinaImg.Mode.ContentIsMask}
        />
      </button>
    );
  }
}

export default ListensToObservable(SendRemindersPopoverButton, {
  getObservable: getMessageObservable,
  getStateFromObservable,
})
