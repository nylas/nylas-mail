import React, {Component, PropTypes} from 'react';
import {RetinaImg} from 'nylas-component-kit';
import {Rx, Message, DatabaseStore, FocusedPerspectiveStore} from 'nylas-exports';
import {getReminderLabel, getLatestMessageWithReminder, setMessageReminder} from './send-reminders-utils'
import {PLUGIN_ID} from './send-reminders-constants';


function canRenderTimestamp(message) {
  const current = FocusedPerspectiveStore.current()
  if (!current.isReminders) {
    return false
  }
  if (!message) {
    return false
  }
  return true
}

class SendRemindersThreadTimestamp extends Component {
  static displayName = 'SendRemindersThreadTimestamp';

  static propTypes = {
    thread: PropTypes.object,
    messages: PropTypes.array,
    fallback: PropTypes.func,
  };

  static containerRequired = false;

  constructor(props) {
    super(props)
    this._disposable = null
    this.state = {
      message: getLatestMessageWithReminder(props.thread, props.messages),
    }
  }

  componentDidMount() {
    const {message} = this.state
    this.setupMessageObservable(message)
  }

  componentWillReceiveProps(nextProps) {
    const {thread, messages} = nextProps
    const message = getLatestMessageWithReminder(thread, messages)
    this.disposeMessageObservable()
    if (!message) {
      this.setState({message})
    } else {
      this.setupMessageObservable(message)
    }
  }

  componentWillUnmount() {
    this.disposeMessageObservable()
  }

  onRemoveReminder(message) {
    setMessageReminder(message.accountId, message, null)
  }

  setupMessageObservable(message) {
    if (!canRenderTimestamp(message)) { return }
    const message$ = Rx.Observable.fromQuery(DatabaseStore.find(Message, message.id))
    this._disposable = message$.subscribe((msg) => {
      const {expiration} = msg.metadataForPluginId(PLUGIN_ID) || {};
      if (!expiration) {
        this.setState({message: null})
      } else {
        this.setState({message: msg})
      }
    })
  }

  disposeMessageObservable() {
    if (this._disposable) {
      this._disposable.dispose()
    }
  }

  render() {
    const {message} = this.state;
    const Fallback = this.props.fallback;
    if (!canRenderTimestamp(message)) {
      return <Fallback {...this.props} />
    }
    const {expiration} = message.metadataForPluginId(PLUGIN_ID);
    const title = getReminderLabel(expiration, {fromNow: true})
    const shortLabel = getReminderLabel(expiration, {shortFormat: true})
    return (
      <span className="send-reminders-thread-timestamp timestamp" title={title}>
        <RetinaImg
          name="ic-timestamp-reminder.png"
          mode={RetinaImg.Mode.ContentIsMask}
        />
        <span className="date-message">
          {shortLabel}
        </span>
      </span>
    )
  }
}

export default SendRemindersThreadTimestamp
