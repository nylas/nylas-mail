import React from 'react';
import {Actions, ReactDOM} from 'nylas-exports';
import {RetinaImg} from 'nylas-component-kit';

import ActivityList from './activity-list';


class ActivityListButton extends React.Component {
  static displayName = 'ActivityListButton';

  constructor() {
    super();
  }

  onClick = () => {
    const buttonRect = ReactDOM.findDOMNode(this).getBoundingClientRect();
    Actions.openPopover(
      <ActivityList />,
      {originRect: buttonRect, direction: 'down'}
    );
  }

  render() {
    return (
      <div
        tabIndex={-1}
        title="View activity"
        onClick={this.onClick}>
        <RetinaImg
          name="icon-toolbar-activity.png"
          className="activity-toolbar-icon"
          mode={RetinaImg.Mode.ContentIsMask} />
      </div>
    );
  }
}

export default ActivityListButton;
