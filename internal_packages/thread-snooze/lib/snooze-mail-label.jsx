import _ from 'underscore';
import React, {Component, PropTypes} from 'react';
import {RetinaImg, MailLabel} from 'nylas-component-kit';
import {SNOOZE_CATEGORY_NAME, PLUGIN_ID} from './snooze-constants';
import {snoozeMessage} from './snooze-utils';


class SnoozeMailLabel extends Component {
  static displayName = 'SnoozeMailLabel';

  static propTypes = {
    thread: PropTypes.object,
  };

  static containerRequired = false;

  render() {
    const {thread} = this.props;
    if (_.findWhere(thread.categories, {displayName: SNOOZE_CATEGORY_NAME})) {
      const metadata = thread.metadataForPluginId(PLUGIN_ID);
      if (metadata) {
        // TODO this is such a hack
        const {snoozeDate} = metadata;
        const message = snoozeMessage(snoozeDate).replace('Snoozed', '')
        const content = (
          <span className="snooze-mail-label">
            <RetinaImg
              name="icon-snoozed.png"
              mode={RetinaImg.Mode.ContentIsMask} />
            <span className="date-message">{message}</span>
          </span>
        )
        const label = {
          displayName: content,
          isLockedCategory: ()=> true,
          hue: ()=> 259,
        }
        return <MailLabel label={label} key={'snooze-message-' + thread.id} />;
      }
      return <span />
    }
    return <span />
  }
}

export default SnoozeMailLabel;
