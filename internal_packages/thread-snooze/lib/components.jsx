/** @babel */
import React, {Component, PropTypes} from 'react';
import {RetinaImg} from 'nylas-component-kit';
import SnoozePopover from './snooze-popover';


const toolbarButton = (
  <button
    className="btn btn-toolbar btn-snooze"
    title="Snooze">
    <RetinaImg
      url="nylas://thread-snooze/assets/ic-toolbar-native-snooze@2x.png"
      mode={RetinaImg.Mode.ContentIsMask} />
  </button>
)

const quickActionButton = (
  <div title="Snooze" className="btn action action-snooze" />
)


export class BulkThreadSnooze extends Component {
  static displayName = 'BulkThreadSnooze';

  static propTypes = {
    selection: PropTypes.object,
    items: PropTypes.array,
  };

  render() {
    return <SnoozePopover buttonComponent={toolbarButton} threads={this.props.items} />;
  }
}

export class ToolbarSnooze extends Component {
  static displayName = 'ToolbarSnooze';

  static propTypes = {
    thread: PropTypes.object,
  };

  render() {
    return <SnoozePopover buttonComponent={toolbarButton} threads={[this.props.thread]} />;
  }
}

export class QuickActionSnooze extends Component {
  static displayName = 'QuickActionSnooze';

  static propTypes = {
    thread: PropTypes.object,
  };

  render() {
    return <SnoozePopover buttonComponent={quickActionButton} threads={[this.props.thread]} />;
  }
}
