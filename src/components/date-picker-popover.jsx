import React, {Component, PropTypes} from 'react'
import {Actions, DateUtils} from 'nylas-exports'
import DateInput from './date-input'
import Menu from './menu'


const {DATE_FORMAT_SHORT, DATE_FORMAT_LONG} = DateUtils

class DatePickerPopover extends Component {
  static displayName = 'DatePickerPopover'

  static propTypes = {
    className: PropTypes.string,
    footer: PropTypes.node,
    onSelectDate: PropTypes.func,
    header: PropTypes.node.isRequired,
    dateOptions: PropTypes.object.isRequired,
    shouldSelectDateWhenInterpreted: PropTypes.bool,
  }

  static defaultProps = {
    shouldSelectDateWhenInterpreted: false,
  }

  onEscape() {
    Actions.closePopover()
  }

  onSelectMenuOption = (optionKey) => {
    const {dateOptions} = this.props
    const date = dateOptions[optionKey]();
    this.refs.dateInput.clearInput()
    this.selectDate(date, optionKey);
  };

  onCustomDateInterpreted = (date) => {
    const {shouldSelectDateWhenInterpreted} = this.props
    if (date && shouldSelectDateWhenInterpreted) {
      this.refs.menu.clearSelection()
      this.selectDate(date, "Custom");
    }
  }

  onCustomDateSelected = (date, inputValue) => {
    if (date) {
      this.refs.menu.clearSelection()
      this.selectDate(date, "Custom");
    } else {
      NylasEnv.showErrorDialog(`Sorry, we can't interpret ${inputValue} as a valid date.`);
    }
  };

  selectDate = (date, dateLabel) => {
    const formatted = DateUtils.format(date.utc());
    this.props.onSelectDate(formatted, dateLabel);
  };

  renderMenuOption = (optionKey) => {
    const {dateOptions} = this.props
    const date = dateOptions[optionKey]();
    const formatted = DateUtils.format(date, DATE_FORMAT_SHORT);
    return (
      <div className="date-picker-popover-option">
        {optionKey}
        <span className="time">{formatted}</span>
      </div>
    );
  }

  render() {
    const {className, header, footer, dateOptions} = this.props

    let footerComponents = [
      <div key="divider" className="divider" />,
      <DateInput
        ref="dateInput"
        key="custom-section"
        className="section date-input-section"
        dateFormat={DATE_FORMAT_LONG}
        onDateSubmitted={this.onCustomDateSelected}
        onDateInterpreted={this.onCustomDateInterpreted}
      />,
    ]
    if (footer) {
      if (Array.isArray(footer)) {
        footerComponents = footerComponents.concat(footer)
      } else {
        footerComponents = footerComponents.concat([footer])
      }
    }

    return (
      <div className={`date-picker-popover ${className}`}>
        <Menu
          ref="menu"
          items={Object.keys(dateOptions)}
          itemKey={item => item}
          itemContent={this.renderMenuOption}
          defaultSelectedIndex={-1}
          headerComponents={header}
          footerComponents={footerComponents}
          onEscape={this.onEscape}
          onSelect={this.onSelectMenuOption}
        />
      </div>
    );
  }
}

export default DatePickerPopover
