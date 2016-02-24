/** @babel */
import React, {Component, PropTypes} from 'react';
import {RetinaImg} from 'nylas-component-kit';
import SnoozePopover from './snooze-popover';


const toolbarButton = (
  <button
    className="btn btn-toolbar btn-snooze"
    title="Snooze">
    <RetinaImg
      name="toolbar-snooze.png"
      mode={RetinaImg.Mode.ContentIsMask} />
  </button>
)

export class BulkThreadSnooze extends Component {
  static displayName = 'BulkThreadSnooze';

  static propTypes = {
    selection: PropTypes.object,
    items: PropTypes.array,
  };

  static containerRequired = false;

  render() {
    return (
      <SnoozePopover
        direction="down"
        buttonComponent={toolbarButton}
        threads={this.props.items} />
    );
  }
}

export class ToolbarSnooze extends Component {
  static displayName = 'ToolbarSnooze';

  static propTypes = {
    thread: PropTypes.object,
  };

  static containerRequired = false;

  render() {
    const pointerStyle = {
      right: 18,
      display: 'block',
    };
    const popoverStyle = {
      transform: 'translate(0, 15px)',
    }
    return (
      <SnoozePopover
        pointerStyle={pointerStyle}
        popoverStyle={popoverStyle}
        buttonComponent={toolbarButton}
        threads={[this.props.thread]} />
    );
  }
}
