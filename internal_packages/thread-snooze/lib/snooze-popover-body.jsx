/** @babel */
import _ from 'underscore';
import React, {Component, PropTypes} from 'react';
import {DateUtils, Actions} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit';
import SnoozeActions from './snooze-actions'
import {DATE_FORMAT_LONG} from './snooze-constants'


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

const SnoozeDateGenerators = {
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


class SnoozePopoverBody extends Component {
  static displayName = 'SnoozePopoverBody';

  static propTypes = {
    threads: PropTypes.array.isRequired,
    swipeCallback: PropTypes.func,
    closePopover: PropTypes.func,
  };

  static defaultProps = {
    swipeCallback: ()=> {},
    closePopover: ()=> {},
  };

  constructor() {
    super();
    this.didSnooze = false;
    this.state = {
      inputDate: null,
    }
  }

  componentWillUnmount() {
    this.props.swipeCallback(this.didSnooze);
  }

  onSnooze(dateGenerator) {
    const utcDate = dateGenerator().utc();
    const formatted = DateUtils.format(utcDate);
    SnoozeActions.snoozeThreads(this.props.threads, formatted);
    this.didSnooze = true;
    this.props.closePopover();

    // if we're looking at a thread, go back to the main view.
    // has no effect otherwise.
    Actions.popSheet();
  }

  onInputChange = (event)=> {
    const inputDate = DateUtils.futureDateFromString(event.target.value)
    this.setState({inputDate})
  };

  onInputKeyDown = (event)=> {
    const {value} = event.target;
    if (value.length > 0 && ["Enter", "Return"].includes(event.key)) {
      const inputDate = DateUtils.futureDateFromString(value);
      if (inputDate) {
        this.onSnooze(()=> inputDate);
      }
    }
  };


  renderItem = (label)=> {
    const dateGenerator = SnoozeDateGenerators[label];
    const iconName = SnoozeIconNames[label];
    const iconPath = `nylas://thread-snooze/assets/ic-snoozepopover-${iconName}@2x.png`;
    return (
      <div
        key={label}
        className="snooze-item"
        onClick={this.onSnooze.bind(this, dateGenerator)}>
        <RetinaImg
          url={iconPath}
          mode={RetinaImg.Mode.ContentIsMask} />
        {label}
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

  renderInputRow = (inputDate)=> {
    let formatted = null;
    if (inputDate) {
      formatted = 'Snooze until ' + DateUtils.format(inputDate, DATE_FORMAT_LONG);
    }
    return (
      <div className="snooze-input">
        <input
          type="text"
          tabIndex="1"
          placeholder="Or type a time, like 'next Monday at 2PM'"
          onKeyDown={this.onInputKeyDown}
          onChange={this.onInputChange}/>
        <span className="input-date-value">{formatted}</span>
      </div>
    );
  };

  render() {
    const {inputDate} = this.state;
    const rows = SnoozeOptions.map(this.renderRow);

    return (
      <div className="snooze-container" tabIndex="-1">
        {rows}
        {this.renderInputRow(inputDate)}
      </div>
    );
  }

}

export default SnoozePopoverBody;
