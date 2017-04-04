import React, {PropTypes} from 'react'
import {DateUtils} from 'nylas-exports'
import {DatePickerPopover} from 'nylas-component-kit'


const SendLaterOptions = {
  'In 1 hour': DateUtils.in1Hour,
  'In 2 hours': DateUtils.in2Hours,
  'Later today': DateUtils.laterToday,
  'Tomorrow morning': DateUtils.tomorrow,
  'Tomorrow evening': DateUtils.tomorrowEvening,
  'This weekend': DateUtils.thisWeekend,
  'Next week': DateUtils.nextWeek,
}

function SendLaterPopover(props) {
  let footer;
  const {onAssignSendLaterDate, onCancelSendLater, sendLaterDate} = props
  const header = <span key="send-later-header">Send later:</span>
  if (sendLaterDate) {
    footer = [
      <div key="divider-unschedule" className="divider" />,
      <div className="section" key="cancel-section">
        <button className="btn btn-cancel" onClick={onCancelSendLater}>
          Unschedule Send
        </button>
      </div>,
    ]
  }

  return (
    <DatePickerPopover
      className="send-later-popover"
      header={header}
      footer={footer}
      dateOptions={SendLaterOptions}
      onSelectDate={onAssignSendLaterDate}
    />
  );
}
SendLaterPopover.displayName = 'SendLaterPopover';
SendLaterPopover.propTypes = {
  sendLaterDate: PropTypes.string,
  onAssignSendLaterDate: PropTypes.func.isRequired,
  onCancelSendLater: PropTypes.func.isRequired,
};

export default SendLaterPopover
