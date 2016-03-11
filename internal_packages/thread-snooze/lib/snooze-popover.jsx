/** @babel */
import _ from 'underscore';
import React, {Component, PropTypes} from 'react';
import {DateUtils, Actions} from 'nylas-exports'
import {RetinaImg, DateInput} from 'nylas-component-kit';
import SnoozeActions from './snooze-actions'

const {DATE_FORMAT_LONG} = DateUtils


const SnoozeOptions = [
  [
    'Later today',
    'Tonight',
    'Tomorrow',
  ],
  [
    'This weekend',
    'Next week',
    'Next month',
  ],
]

const SnoozeDatesFactory = {
  'Later today': DateUtils.laterToday,
  'Tonight': DateUtils.tonight,
  'Tomorrow': DateUtils.tomorrow,
  'This weekend': DateUtils.thisWeekend,
  'Next week': DateUtils.nextWeek,
  'Next month': DateUtils.nextMonth,
}

const SnoozeIconNames = {
  'Later today': 'later',
  'Tonight': 'tonight',
  'Tomorrow': 'tomorrow',
  'This weekend': 'weekend',
  'Next week': 'week',
  'Next month': 'month',
}


class SnoozePopover extends Component {
  static displayName = 'SnoozePopover';

  static propTypes = {
    threads: PropTypes.array.isRequired,
    swipeCallback: PropTypes.func,
  };

  static defaultProps = {
    swipeCallback: ()=> {},
  };

  constructor() {
    super();
    this.didSnooze = false;
  }

  componentWillUnmount() {
    this.props.swipeCallback(this.didSnooze);
  }

  onSnooze(date, itemLabel) {
    const utcDate = date.utc();
    const formatted = DateUtils.format(utcDate);
    SnoozeActions.snoozeThreads(this.props.threads, formatted, itemLabel);
    this.didSnooze = true;
    Actions.closePopover();

    // if we're looking at a thread, go back to the main view.
    // has no effect otherwise.
    Actions.popSheet();
  }

  onSelectCustomDate = (date, inputValue)=> {
    if (date) {
      this.onSnooze(date, "Custom");
    } else {
      NylasEnv.showErrorDialog(`Sorry, we can't parse ${inputValue} as a valid date.`);
    }
  };

  renderItem = (itemLabel)=> {
    const date = SnoozeDatesFactory[itemLabel]();
    const iconName = SnoozeIconNames[itemLabel];
    const iconPath = `nylas://thread-snooze/assets/ic-snoozepopover-${iconName}@2x.png`;
    return (
      <div
        key={itemLabel}
        className="snooze-item"
        onClick={this.onSnooze.bind(this, date, itemLabel)}>
        <RetinaImg
          url={iconPath}
          mode={RetinaImg.Mode.ContentIsMask} />
        {itemLabel}
      </div>
    )
  };

  renderRow = (options, idx)=> {
    const items = _.map(options, this.renderItem);
    return (
      <div key={`snooze-popover-row-${idx}`} className="snooze-row">
        {items}
      </div>
    );
  };

  render() {
    const rows = SnoozeOptions.map(this.renderRow);

    return (
      <div className="snooze-popover" tabIndex="-1">
        {rows}
        <DateInput
          className="snooze-input"
          dateFormat={DATE_FORMAT_LONG}
          onSubmitDate={this.onSelectCustomDate} />
      </div>
    );
  }

}

export default SnoozePopover;
