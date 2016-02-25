/** @babel */
import React, {Component, PropTypes} from 'react';
import {Actions} from 'nylas-exports';
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

  closePopover = ()=> {
    this.refs.popover.close();
  };

  render() {
    const {buttonComponent, direction, popoverStyle, pointerStyle, threads} = this.props

    return (
      <Popover
        ref="popover"
        className="snooze-popover"
        direction={direction || 'down-align-left'}
        buttonComponent={buttonComponent}
        popoverStyle={popoverStyle}
        pointerStyle={pointerStyle}
        onOpened={()=> Actions.closePopover()}>
        <SnoozePopoverBody
          threads={threads}
          closePopover={this.closePopover}/>
      </Popover>
    );
  }

}

export default SnoozePopover;
