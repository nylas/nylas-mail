import React from 'react'
import moment from 'moment';
import PropTypes from 'prop-types'
import {RetinaImg} from 'nylas-component-kit'
import {DateUtils} from 'nylas-exports';

import {updateReminderMetadata} from './send-reminders-utils'
import {PLUGIN_ID} from './send-reminders-constants'


export function NotificationExplanationMessageHeader({thread, message}) {
  const {shouldNotify, sentHeaderMessageId} = thread.metadataForPluginId(PLUGIN_ID) || {};

  if (!shouldNotify) {
    return <span />
  }
  if (message.headerMessageId !== sentHeaderMessageId) {
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

NotificationExplanationMessageHeader.displayName = 'NotificationExplanationMessageHeader'
NotificationExplanationMessageHeader.containerRequired = false
NotificationExplanationMessageHeader.propTypes = {
  messages: PropTypes.array,
  message: PropTypes.object,
  thread: PropTypes.object,
}

export function ScheduledReminderThreadHeader({thread}) {
  const metadata = thread.metadataForPluginId(PLUGIN_ID) || {};
  if (!metadata.expiration) {
    return <span />
  }

  const onClearReminder = () => {
    updateReminderMetadata(thread, Object.assign(metadata, {expiration: null}))
  }

  return (
    <div className="send-reminders-header">
      <RetinaImg
        name="ic-timestamp-reminder.png"
        mode={RetinaImg.Mode.ContentIsMask}
      />
      <span className="reminder-date">
        {` ${moment(metadata.expiration).format(DateUtils.DATE_FORMAT_LONG_NO_YEAR)}`}
      </span>
      <span className="clear-reminder" onClick={onClearReminder}>Cancel</span>
    </div>
  )
}
ScheduledReminderThreadHeader.displayName = 'ScheduledReminderThreadHeader'
ScheduledReminderThreadHeader.containerRequired = false
ScheduledReminderThreadHeader.propTypes = {
  thread: PropTypes.object,
  messages: PropTypes.array,
}
