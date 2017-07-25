import React from 'react';
import {Actions, ReactDOM} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';

import ActivityList from './activity-list';
import ActivityListStore from './activity-list-store';


class ActivityListButton extends React.Component {
  static displayName = 'ActivityListButton';

  constructor() {
    super();
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    this._unsub = ActivityListStore.listen(this._onDataChanged);
  }

  componentWillUnmount() {
    this._unsub();
  }

  onClick = () => {
    const buttonRect = ReactDOM.findDOMNode(this).getBoundingClientRect();
    Actions.openPopover(
      <ActivityList />,
      {originRect: buttonRect, direction: 'down'}
    );
  }

  _onDataChanged = () => {
    this.setState(this._getStateFromStores());
  }

  _getStateFromStores() {
    return {
      unreadCount: ActivityListStore.unreadCount(),
    }
  }

  render() {
    let unreadCountClass = "unread-count";
    let iconClass = "activity-toolbar-icon";
    if (this.state.unreadCount) {
      unreadCountClass += " active";
      iconClass += " unread";
    }
    return (
      <div
        tabIndex={-1}
        className="toolbar-activity"
        title="View activity"
        onClick={this.onClick}
      >
        <div className={unreadCountClass}>
          {this.state.unreadCount}
        </div>
        <RetinaImg
          name="icon-toolbar-activity.png"
          className={iconClass}
          mode={RetinaImg.Mode.ContentIsMask}
        />
      </div>
    );
  }
}

export default ActivityListButton;
