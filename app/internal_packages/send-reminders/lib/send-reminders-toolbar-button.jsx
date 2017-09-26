import React from 'react';
import PropTypes from 'prop-types';
import { HasTutorialTip } from 'nylas-component-kit';
import SendRemindersPopoverButton from './send-reminders-popover-button';

const SendRemindersPopoverButtonWithTip = HasTutorialTip(SendRemindersPopoverButton, {
  title: 'Get reminded!',
  instructions:
    "Get reminded if you don't receive a reply for this message within a specified time.",
});

export default function SendRemindersToolbarButton(props) {
  const threads = props.items;
  if (threads.length > 1) {
    return <span />;
  }
  const thread = threads[0];

  // you can only set a reminder if the last message on the thread was sent by you
  if (thread.lastMessageSentTimestamp < thread.lastMessageReceivedTimestamp) {
    return <span />;
  }

  return <SendRemindersPopoverButtonWithTip thread={thread} />;
}

SendRemindersToolbarButton.containerRequired = false;
SendRemindersToolbarButton.displayName = 'SendRemindersToolbarButton';
SendRemindersToolbarButton.propTypes = {
  items: PropTypes.array,
};
