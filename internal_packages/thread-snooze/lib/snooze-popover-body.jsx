/** @babel */
import _ from 'underscore';
import React, {Component, PropTypes} from 'react';
import {DateUtils} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit';
import SnoozeActions from './snooze-actions'
import {DATE_FORMAT_LONG} from './snooze-constants'


const SnoozeOptions = [
  [
    'Later Today',
    'Tonight',
    'Tomorrow',
  ],
  [
    'This Weekend',
    'Next Week',
    'Next Month',
  ],
]

const SnoozeDateGenerators = {
  'Later Today': DateUtils.laterToday,
  'Tonight': DateUtils.tonight,
  'Tomorrow': DateUtils.tomorrow,
  'This Weekend': DateUtils.thisWeekend,
  'Next Week': DateUtils.nextWeek,
  'Next Month': DateUtils.nextMonth,
}

const SnoozeIconNames = {
  'Later Today': 'later',
  'Tonight': 'tonight',
  'Tomorrow': 'tomorrow',
  'This Weekend': 'weekend',
  'Next Week': 'week',
  'Next Month': 'month',
}


class SnoozePopoverBody extends Component {
  static displayName = 'SnoozePopoverBody';

  static propTypes = {
    threads: PropTypes.array.isRequired,
    isFixedPopover: PropTypes.bool,
    swipeCallback: PropTypes.func,
    closePopover: PropTypes.func,
  };

  static defaultProps = {
    isFixedPopover: true,
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
    const utcDate = dateGenerator().utc()
    const formatted = DateUtils.format(utcDate)
    SnoozeActions.snoozeThreads(this.props.threads, formatted);
    this.didSnooze = true;
    this.props.closePopover()
  }

  onBlur = ()=> {
    if (!this.props.isFixedPopover) return;
    if (this._focusingInput) {
      this._focusingInput = false;
      return;
    }
    this.props.closePopover();
  };

  onKeyDown = (event)=> {
    if (!this.props.isFixedPopover) return;
    if (event.key === "Escape") {
      this.props.closePopover();
    }
  };

  onInputChange = (event)=> {
    const inputDate = DateUtils.futureDateFromString(event.target.value)
    this.setState({inputDate})
  };

  onInputKeyDown = (event)=> {
    const {value} = event.target;
    if (value.length > 0 && ["Enter", "Return"].includes(event.key)) {
      const inputDate = DateUtils.futureDateFromString(value)
      if (inputDate) {
        this.onSnooze(()=> inputDate)
      }
    }
  };

  onInputMouseDown = ()=> {
    this._focusingInput = true;
  };

  renderItem = (label)=> {
    const dateGenerator = SnoozeDateGenerators[label];
    const iconName = SnoozeIconNames[label]
    const iconPath = `nylas://thread-snooze/assets/ic-snoozepopover-${iconName}@2x.png`
    return (
      <div
        key={label}
        className="snooze-item"
        onMouseDown={this.onSnooze.bind(this, dateGenerator)}>
        <RetinaImg
          url={iconPath}
          mode={RetinaImg.Mode.ContentPreserve} />
        {label}
      </div>
    )
  };

  renderRow = (options, idx)=> {
    const items = _.map(options, this.renderItem)
    return (
      <div key={`snooze-popover-row-${idx}`} className="snooze-row">
        {items}
      </div>
    );
  };

  renderInputRow = (inputDate)=> {
    let formatted = null
    if (inputDate) {
      formatted = 'Snooze until ' + DateUtils.format(inputDate, DATE_FORMAT_LONG)
    }
    return (
      <div className="snooze-input">
        <input
          type="text"
          tabIndex="1"
          placeholder="Or type a time, like 'next Monday at 2PM'"
          onMouseDown={this.onInputMouseDown}
          onKeyDown={this.onInputKeyDown}
          onChange={this.onInputChange}/>
        <span className="input-date-value">{formatted}</span>
      </div>
    );
  };

  render() {
    const {inputDate} = this.state
    const rows = SnoozeOptions.map(this.renderRow)

    return (
      <div className="snooze-container" onBlur={this.onBlur} onKeyDown={this.onKeyDown}>
        {rows}
        {this.renderInputRow(inputDate)}
      </div>
    );
  }

}

export default SnoozePopoverBody;
