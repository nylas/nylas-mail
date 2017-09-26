import React, { Component } from 'react';
import PropTypes from 'prop-types';
import ReactDOM from 'react-dom';
import { Actions } from 'nylas-exports';
import { RetinaImg } from 'nylas-component-kit';
import moment from 'moment';

import SendRemindersPopover from './send-reminders-popover';
import { reminderDateFor, updateDraftReminderMetadata } from './send-reminders-utils';

export default class SendRemindersComposerButton extends Component {
  static displayName = 'SendRemindersComposerButton';

  static containerRequired = false;

  static propTypes = {
    draft: PropTypes.object.isRequired,
    session: PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props);
    this.state = {
      saving: false,
    };
  }

  componentWillReceiveProps() {
    if (this.state.saving) {
      this.setState({ saving: false });
    }
  }

  shouldComponentUpdate(nextProps) {
    return reminderDateFor(nextProps.draft) !== reminderDateFor(this.props.draft);
  }

  onSetReminder = reminderDate => {
    const { draft, session } = this.props;
    this.setState({ saving: true });

    updateDraftReminderMetadata(session, {
      expiration: reminderDate,
      sentHeaderMessageId: draft.headerMessageId,
    });

    Actions.closePopover();
  };

  onClick = () => {
    const { draft } = this.props;
    const buttonRect = ReactDOM.findDOMNode(this).getBoundingClientRect();
    Actions.openPopover(
      <SendRemindersPopover
        reminderDate={reminderDateFor(draft)}
        onRemind={date => this.onSetReminder(date)}
        onCancelReminder={() => this.onSetReminder(null)}
      />,
      { originRect: buttonRect, direction: 'up' }
    );
  };

  render() {
    let className = 'btn btn-toolbar btn-send-reminder';

    if (this.state.saving) {
      return (
        <button className={className} title="Saving reminder..." tabIndex={-1}>
          <RetinaImg
            name="inline-loading-spinner.gif"
            mode={RetinaImg.Mode.ContentDark}
            style={{ width: 14, height: 14 }}
          />
        </button>
      );
    }

    const reminderDate = reminderDateFor(this.props.draft);
    let reminderLabel = 'Set reminder';
    if (reminderDate) {
      className += ' btn-enabled';
      reminderLabel = `Reminder set for ${moment(reminderDate).fromNow(true)} from now`;
    }

    return (
      <button tabIndex={-1} className={className} title={reminderLabel} onClick={this.onClick}>
        <RetinaImg name="icon-composer-reminders.png" mode={RetinaImg.Mode.ContentIsMask} />
        <span>&nbsp;</span>
        <RetinaImg name="icon-composer-dropdown.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }
}
