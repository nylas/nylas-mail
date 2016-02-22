/** @babel */
import React, {Component, PropTypes} from 'react';
import {Popover} from 'nylas-component-kit';
import SnoozePopoverBody from './snooze-popover-body';


class SnoozePopover extends Component {
  static displayName = 'SnoozePopover';

  static propTypes = {
    threads: PropTypes.array.isRequired,
    buttonComponent: PropTypes.object.isRequired,
    direction: PropTypes.string,
    pointerStyle: PropTypes.object,
    popoverStyle: PropTypes.object,
  };

  render() {
    const {buttonComponent, direction, popoverStyle, pointerStyle, threads} = this.props

    return (
      <Popover
        className="snooze-popover"
        direction={direction || 'down-align-left'}
        buttonComponent={buttonComponent}
        popoverStyle={popoverStyle}
        pointerStyle={pointerStyle}>
        <SnoozePopoverBody threads={threads}/>
      </Popover>
    );
  }

}

export default SnoozePopover;
