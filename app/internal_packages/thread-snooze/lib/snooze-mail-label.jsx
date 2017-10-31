import React, { Component } from 'react';
import PropTypes from 'prop-types';
import { FocusedPerspectiveStore } from 'mailspring-exports';
import { RetinaImg, MailLabel } from 'mailspring-component-kit';
import { PLUGIN_ID } from './snooze-constants';
import { snoozedUntilMessage } from './snooze-utils';

class SnoozeMailLabel extends Component {
  static displayName = 'SnoozeMailLabel';

  static propTypes = {
    thread: PropTypes.object,
  };

  static containerRequired = false;

  render() {
    const current = FocusedPerspectiveStore.current();
    const isSnoozedPerspective =
      current.categories().length > 0 && current.categories()[0].role === 'snoozed';

    if (!isSnoozedPerspective) {
      return false;
    }

    const { thread } = this.props;
    if (!thread.categories.find(c => c.role === 'snoozed')) {
      return false;
    }

    const metadata = thread.metadataForPluginId(PLUGIN_ID);
    if (!metadata || !metadata.expiration) {
      return false;
    }
    const content = (
      <span className="snooze-mail-label">
        <RetinaImg name="icon-snoozed.png" mode={RetinaImg.Mode.ContentIsMask} />
        <span className="date-message">
          {snoozedUntilMessage(metadata.expiration).replace('Snoozed', '')}
        </span>
      </span>
    );
    const label = {
      displayName: content,
      isLockedCategory: () => true,
      hue: () => 259,
    };
    return <MailLabel label={label} key={`snooze-message-${thread.id}`} />;
  }
}

export default SnoozeMailLabel;
