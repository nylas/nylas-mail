import React from 'react';
import {DateUtils} from 'nylas-exports';
import {Flexbox} from 'nylas-component-kit';
import ActivityListStore from '../../activity-list/lib/activity-list-store';


class LinkTrackingMessagePopover extends React.Component {
  static displayName = 'LinkTrackingMessagePopover';

  static propTypes = {
    message: React.PropTypes.object,
    linkMetadata: React.PropTypes.object,
  };

  renderClickActions() {
    const clicks = this.props.linkMetadata.click_data;
    return clicks.map((click) => {
      const recipients = this.props.message.to.concat(this.props.message.cc, this.props.message.bcc);
      const recipient = ActivityListStore.getRecipient(click.recipient, recipients);
      const date = new Date(0);
      date.setUTCSeconds(click.timestamp);
      return (
        <Flexbox key={`${click.timestamp}`} className="click-action">
          <div className="recipient">
            {recipient ? recipient.displayName() : "Someone"}
          </div>
          <div className="spacer" />
          <div className="timestamp">
            {DateUtils.shortTimeString(date)}
          </div>
        </Flexbox>
      );
    });
  }

  render() {
    return (
      <div
        className="link-tracking-message-popover"
        tabIndex="-1"
      >
        <div className="link-tracking-header">Clicked by:</div>
        <div className="click-history-container">
          {this.renderClickActions()}
        </div>
      </div>
    );
  }
}

export default LinkTrackingMessagePopover;
