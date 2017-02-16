import React, {PropTypes} from 'react'
import {DateUtils} from 'nylas-exports'
import {DatePickerPopover} from 'nylas-component-kit'
import {getReminderLabel} from './send-reminders-utils'


const SendRemindersOptions = {
  'In 1 hour': DateUtils.in1Hour,
  'In 2 hours': DateUtils.in2Hours,
  'In 4 hours': () => DateUtils.minutesFromNow(240),
  'Tomorrow morning': DateUtils.tomorrow,
  'Tomorrow evening': DateUtils.tomorrowEvening,
  'In 2 days': () => DateUtils.hoursFromNow(48),
  'In 4 days': () => DateUtils.hoursFromNow(96),
  'In 1 week': () => DateUtils.weeksFromNow(1),
  'In 2 weeks': () => DateUtils.weeksFromNow(2),
  'In 1 month': () => DateUtils.monthsFromNow(1),
}

function SendRemindersPopover(props) {
  const {reminderDate, onRemind, onCancelReminder} = props
  const header = <span key="reminders-header">Remind me if no one replies:</span>
  const footer = [
    reminderDate ? <div key="reminders-divider" className="divider" /> : null,
    reminderDate ?
      <div
        key="send-reminders-footer"
        className="section send-reminders-footer"
      >
        <div className="reminders-label">
          <span>
            This thread will come back to the top of your inbox if nobody replies by:
            <span className="reminder-date">
              {` ${getReminderLabel(reminderDate)}`}
            </span>
          </span>
        </div>
        <button className="btn btn-cancel" onClick={onCancelReminder}>
          Clear reminder
        </button>
      </div> :
      null,
  ]

  return (
    <DatePickerPopover
      className="send-reminders-popover"
      header={header}
      footer={footer}
      onSelectDate={onRemind}
      dateOptions={SendRemindersOptions}
    />
  );
}
SendRemindersPopover.displayName = 'SendRemindersPopover';

SendRemindersPopover.propTypes = {
  reminderDate: PropTypes.string,
  onRemind: PropTypes.func,
  onCancelReminder: PropTypes.func,
};


export default SendRemindersPopover
