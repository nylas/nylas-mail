import React, {PropTypes} from 'react'
import {RetinaImg} from 'nylas-component-kit'
import {FocusedPerspectiveStore} from 'nylas-exports'
import {getReminderLabel, getLatestMessage, getLatestMessageWithReminder} from './send-reminders-utils'
import {PLUGIN_ID} from './send-reminders-constants'


export function MessageHeader(props) {
  const {thread, messages, message} = props
  const {shouldNotify} = thread.metadataForPluginId(PLUGIN_ID) || {}
  if (!shouldNotify) {
    return <span />
  }
  const latestMessage = getLatestMessage(thread, messages)
  if (message.id !== latestMessage.id) {
    return <span />
  }
  return (
    <div className="send-reminders-header">
      <RetinaImg
        name="ic-timestamp-reminder.png"
        mode={RetinaImg.Mode.ContentIsMask}
      />
      <span title="This thread was brought back to the top of your inbox as a reminder">
        Reminder
      </span>
    </div>
  )
}
MessageHeader.displayName = 'MessageHeader'
MessageHeader.containerRequired = false
MessageHeader.propTypes = {
  messages: PropTypes.array,
  message: PropTypes.object,
  thread: PropTypes.object,
}

export function ThreadHeader(props) {
  const current = FocusedPerspectiveStore.current()
  if (!current.isReminders) {
    return <span />
  }
  const {thread, messages} = props
  const message = getLatestMessageWithReminder(thread, messages)
  if (!message) {
    return <span />
  }
  const {reminderDate} = message.metadataForPluginId(PLUGIN_ID) || {}
  return (
    <div className="send-reminders-header">
      <RetinaImg
        name="ic-timestamp-reminder.png"
        mode={RetinaImg.Mode.ContentIsMask}
      />
      <span>
        This thread will come back to the top of your inbox if nobody replies by: <br />
        <span className="reminder-date">
          {` ${getReminderLabel(reminderDate)}`}
        </span>
      </span>
    </div>
  )
}
ThreadHeader.displayName = 'ThreadHeader'
ThreadHeader.containerRequired = false
ThreadHeader.propTypes = {
  thread: PropTypes.object,
  messages: PropTypes.array,
}
