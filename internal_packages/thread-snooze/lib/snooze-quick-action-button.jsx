import React, {Component, PropTypes} from 'react';
import {Actions, FocusedPerspectiveStore} from 'nylas-exports';
import SnoozePopoverBody from './snooze-popover-body';


class QuickActionSnoozeButton extends Component {
  static displayName = 'QuickActionSnoozeButton';

  static propTypes = {
    thread: PropTypes.object,
  };

  onClick = (event)=> {
    event.stopPropagation()
    const {thread} = this.props;

    // Grab the parent node because of the zoom applied to this button. If we
    // took this element directly, we'd have to divide everything by 2
    const element = React.findDOMNode(this).parentNode;
    const {height, width, top, bottom, left, right} = element.getBoundingClientRect()

    // The parent node is a bit too much to the left, lets adjust this.
    const rect = {height, width, top, bottom, right, left: left + 5}
    Actions.openPopover(
      <SnoozePopoverBody threads={[thread]} closePopover={Actions.closePopover}/>,
      rect,
      "left"
    );
  };

  static containerRequired = false;

  render() {
    if (!FocusedPerspectiveStore.current().isInbox()) {
      return <span />;
    }
    return <div title="Snooze" className="btn action action-snooze" onClick={this.onClick}/>
  }
}

export default QuickActionSnoozeButton
