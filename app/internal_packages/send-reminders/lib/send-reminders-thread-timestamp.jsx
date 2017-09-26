import React, { Component } from 'react';
import PropTypes from 'prop-types';
import { RetinaImg } from 'mailspring-component-kit';
import moment from 'moment';

import { FocusedPerspectiveStore } from 'mailspring-exports';
import { updateReminderMetadata } from './send-reminders-utils';
import { PLUGIN_ID } from './send-reminders-constants';

class SendRemindersThreadTimestamp extends Component {
  static displayName = 'SendRemindersThreadTimestamp';

  static propTypes = {
    thread: PropTypes.object,
    fallback: PropTypes.func,
  };

  static containerRequired = false;

  onRemoveReminder(thread) {
    updateReminderMetadata(thread, {});
  }

  render() {
    const Fallback = this.props.fallback;
    const current = FocusedPerspectiveStore.current();

    if (!current.isReminders) {
      return <Fallback {...this.props} />;
    }

    const { expiration } = this.props.thread.metadataForPluginId(PLUGIN_ID);
    if (!expiration) {
      return <Fallback {...this.props} />;
    }

    const mExpiration = moment(expiration);

    return (
      <span
        className="send-reminders-thread-timestamp timestamp"
        title={`Reminder set for ${mExpiration.fromNow(true)} from now`}
      >
        <RetinaImg name="ic-timestamp-reminder.png" mode={RetinaImg.Mode.ContentIsMask} />
        <span className="date-message">{`in ${mExpiration.fromNow(true)}`}</span>
      </span>
    );
  }
}

export default SendRemindersThreadTimestamp;
