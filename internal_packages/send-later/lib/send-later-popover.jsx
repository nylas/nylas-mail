/** @babel */
import React, {Component, PropTypes} from 'react'
import {DateUtils} from 'nylas-exports'
import {Menu, DateInput} from 'nylas-component-kit'

const {DATE_FORMAT_SHORT, DATE_FORMAT_LONG} = DateUtils


const SendLaterOptions = {
  'In 1 hour': DateUtils.in1Hour,
  'In 2 hours': DateUtils.in2Hours,
  'Later today': DateUtils.laterToday,
  'Tomorrow morning': DateUtils.tomorrow,
  'Tomorrow evening': DateUtils.tomorrowEvening,
  'This weekend': DateUtils.thisWeekend,
  'Next week': DateUtils.nextWeek,
}

class SendLaterPopover extends Component {
  static displayName = 'SendLaterPopover';

  static propTypes = {
    scheduledDate: PropTypes.string,
    onSendLater: PropTypes.func.isRequired,
    onCancelSendLater: PropTypes.func.isRequired,
  };

  onSelectMenuOption = (optionKey)=> {
    const date = SendLaterOptions[optionKey]();
    this.selectDate(date, optionKey);
  };

  onSelectCustomOption = (date, inputValue)=> {
    if (date) {
      this.selectDate(date, "Custom");
    } else {
      NylasEnv.showErrorDialog(`Sorry, we can't parse ${inputValue} as a valid date.`);
    }
  };

  selectDate = (date, dateLabel)=> {
    const formatted = DateUtils.format(date.utc());
    this.props.onSendLater(formatted, dateLabel);
  };

  renderMenuOption(optionKey) {
    const date = SendLaterOptions[optionKey]();
    const formatted = DateUtils.format(date, DATE_FORMAT_SHORT);
    return (
      <div className="send-later-option">
        {optionKey}
        <span className="time">{formatted}</span>
      </div>
    );
  }

  render() {
    const headerComponents = [
      <span key="send-later-header">Send later:</span>,
    ]
    const footerComponents = [
      <div key="divider" className="divider" />,
      <DateInput
        key="custom"
        className="custom-section"
        dateFormat={DATE_FORMAT_LONG}
        onSubmitDate={this.onSelectCustomOption} />,
    ];

    if (this.props.scheduledDate) {
      footerComponents.push(<div key="divider-unschedule" className="divider" />)
      footerComponents.push(
        <div className="cancel-section" key="cancel-section">
          <button className="btn btn-cancel" onClick={this.props.onCancelSendLater}>
            Unschedule Send
          </button>
        </div>
      )
    }

    return (
      <div
        className="send-later">
        <Menu
          ref="menu"
          items={Object.keys(SendLaterOptions)}
          itemKey={item => item}
          itemContent={this.renderMenuOption}
          defaultSelectedIndex={-1}
          headerComponents={headerComponents}
          footerComponents={footerComponents}
          onSelect={this.onSelectMenuOption} />
      </div>
    );
  }

}

export default SendLaterPopover
