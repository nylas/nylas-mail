/** @babel */
import _ from 'underscore';
import React, {Component, PropTypes} from 'react';
import {DateUtils} from 'nylas-exports'
import {Popover} from 'nylas-component-kit';
import SnoozeActions from './snooze-actions'


const SnoozeOptions = {
  'Later Today': DateUtils.laterToday,
  'Tonight': DateUtils.tonight,
  'Tomorrow': DateUtils.tomorrow,
  'This Weekend': DateUtils.thisWeekend,
  'Next Week': DateUtils.nextWeek,
  'Next Month': DateUtils.nextMonth,
}

class SnoozePopover extends Component {
  static displayName = 'SnoozePopover';

  static propTypes = {
    threads: PropTypes.array.isRequired,
    buttonComponent: PropTypes.object.isRequired,
  };

  onSnooze(dateGenerator) {
    const utcDate = dateGenerator().utc()
    const formatted = DateUtils.format(utcDate)
    SnoozeActions.snoozeThreads(this.props.threads, formatted)
  }

  renderItem = (label, dateGenerator)=> {
    return (
      <div
        key={label}
        className="snooze-item"
        onMouseDown={this.onSnooze.bind(this, dateGenerator)}>
        {label}
      </div>
    )
  };

  render() {
    const {buttonComponent} = this.props
    const items = _.map(SnoozeOptions, (dateGenerator, label)=> this.renderItem(label, dateGenerator))

    return (
      <Popover
        style={{order: -103}}
        className="snooze-popover"
        direction="down-align-left"
        buttonComponent={buttonComponent}>
        <div className="snooze-container">
          {items}
        </div>
      </Popover>
    );
  }

}

export default SnoozePopover;
