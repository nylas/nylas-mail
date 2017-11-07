import { React, PropTypes, DateUtils } from 'mailspring-exports';
import { Flexbox } from 'mailspring-component-kit';
import ActivityEventStore from '../../activity/lib/activity-event-store';

class LinkTrackingMessagePopover extends React.Component {
  static displayName = 'LinkTrackingMessagePopover';

  static propTypes = {
    message: PropTypes.object,
    linkMetadata: PropTypes.object,
  };

  renderClickActions() {
    const clicks = this.props.linkMetadata.click_data;
    return clicks.map(click => {
      const recipients = this.props.message.to.concat(
        this.props.message.cc,
        this.props.message.bcc
      );
      const recipient = ActivityEventStore.getRecipient(click.recipient, recipients);
      const date = new Date(0);
      date.setUTCSeconds(click.timestamp);
      return (
        <Flexbox key={`${click.timestamp}`} className="click-action">
          <div className="recipient">{recipient ? recipient.displayName() : 'Someone'}</div>
          <div className="spacer" />
          <div className="timestamp">{DateUtils.shortTimeString(date)}</div>
        </Flexbox>
      );
    });
  }

  render() {
    return (
      <div className="link-tracking-message-popover" tabIndex="-1">
        <div className="link-tracking-header">Clicked by:</div>
        <div className="click-history-container">{this.renderClickActions()}</div>
      </div>
    );
  }
}

export default LinkTrackingMessagePopover;
