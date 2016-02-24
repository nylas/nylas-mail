import React, {Component, PropTypes} from 'react';
import {PopoverStore, Actions} from 'nylas-exports';
import SnoozePopoverBody from './snooze-popover-body';


class QuickActionSnoozeButton extends Component {
  static displayName = 'QuickActionSnoozeButton';

  static propTypes = {
    thread: PropTypes.object,
  };

  constructor() {
    super();
  }

  onClick = (event)=> {
    event.stopPropagation()
    if (PopoverStore.isPopoverOpen()) {
      Actions.closePopover();
      return;
    }
    const {thread} = this.props;

    // Grab the parent node because of the zoom applied to this button. If we
    // took this element directly, we'd have to divide everything by 2
    const element = React.findDOMNode(this).parentNode;
    const {height, width, top, bottom, left, right} = element.getBoundingClientRect()

    // The parent node is a bit too much to the left, lets adjust this.
    const rect = {height, width, top, bottom, right, left: left + 5}
    Actions.openPopover(
      <SnoozePopoverBody threads={[thread]}/>,
      rect,
      "left"
    )
  };

  static containerRequired = false;

  render() {
    return <div title="Snooze" className="btn action action-snooze" onClick={this.onClick}/>
  }
}

export default QuickActionSnoozeButton
