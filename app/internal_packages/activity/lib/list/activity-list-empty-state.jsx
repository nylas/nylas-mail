import React from 'react';
import { RetinaImg } from 'mailspring-component-kit';

const ActivityListEmptyState = function ActivityListEmptyState() {
  return (
    <div className="empty-state-container">
      <RetinaImg
        className="logo"
        name="activity-list-empty.png"
        mode={RetinaImg.Mode.ContentIsMask}
      />
      <div className="text">
        Enable read receipts{' '}
        <RetinaImg name="icon-activity-mailopen.png" mode={RetinaImg.Mode.ContentDark} /> or link
        tracking <RetinaImg
          name="icon-activity-linkopen.png"
          mode={RetinaImg.Mode.ContentDark}
        />{' '}
        to see notifications here.
      </div>
    </div>
  );
};

export default ActivityListEmptyState;
