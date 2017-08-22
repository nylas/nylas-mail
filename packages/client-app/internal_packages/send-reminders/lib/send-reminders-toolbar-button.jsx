import React, {PropTypes} from 'react';
import {HasTutorialTip} from 'nylas-component-kit';
import {getLatestMessage} from './send-reminders-utils'
import SendRemindersPopoverButton from './send-reminders-popover-button';

const SendRemindersPopoverButtonWithTip = HasTutorialTip(SendRemindersPopoverButton, {
  title: "Get reminded!",
  instructions: "Get reminded if you don't receive a reply for this message within a specified time.",
});

function canSetReminderOnThread(thread) {
  const {from} = getLatestMessage(thread) || {}
  return (
    from && from.length > 0 && from[0].isMe()
  )
}

export default function SendRemindersToolbarButton(props) {
  const threads = props.items
  if (threads.length > 1) {
    return <span />;
  }
  const thread = threads[0]
  if (!canSetReminderOnThread(thread)) {
    return <span />;
  }
  return (
    <SendRemindersPopoverButtonWithTip thread={thread} />
  );
}

SendRemindersToolbarButton.containerRequired = false;
SendRemindersToolbarButton.displayName = 'SendRemindersToolbarButton';
SendRemindersToolbarButton.propTypes = {
  items: PropTypes.array,
};
