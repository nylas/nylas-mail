import React, {Component, PropTypes} from 'react'
import ReactDOM from 'react-dom'
import {Actions} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import SendRemindersPopover from './send-reminders-popover'
import {setDraftReminder, reminderDateForMessage, getReminderLabel} from './send-reminders-utils'


class SendRemindersComposerButton extends Component {
  static displayName = 'SendRemindersComposerButton';

  static containerRequired = false;

  static propTypes = {
    draft: PropTypes.object.isRequired,
    session: PropTypes.object.isRequired,
  };

  constructor(props) {
    super(props)
    this.state = {
      saving: false,
    }
  }

  componentWillReceiveProps() {
    if (this.state.saving) {
      this.setState({saving: false})
    }
  }

  shouldComponentUpdate(nextProps) {
    if (reminderDateForMessage(nextProps.draft) !== reminderDateForMessage(this.props.draft)) {
      return true;
    }
    return false;
  }

  onSetReminder = (reminderDate, dateLabel) => {
    const {draft, session} = this.props
    this.setState({saving: true})
    setDraftReminder(draft.accountId, session, reminderDate, dateLabel)
  }

  onClick = () => {
    const {draft} = this.props
    const buttonRect = ReactDOM.findDOMNode(this).getBoundingClientRect()
    Actions.openPopover(
      <SendRemindersPopover
        onRemind={this.onSetReminder}
        reminderDate={reminderDateForMessage(draft)}
        onCancelReminder={() => this.onSetReminder(null)}
      />,
      {originRect: buttonRect, direction: 'up'}
    )
  };

  render() {
    const {saving} = this.state
    let className = 'btn btn-toolbar btn-send-reminder';

    if (saving) {
      return (
        <button className={className} title="Saving reminder..." tabIndex={-1}>
          <RetinaImg
            name="inline-loading-spinner.gif"
            mode={RetinaImg.Mode.ContentDark}
            style={{width: 14, height: 14}}
          />
        </button>
      );
    }

    const {draft} = this.props
    const reminderDate = reminderDateForMessage(draft);
    let reminderLabel = 'Set reminder';
    if (reminderDate) {
      className += ' btn-enabled';
      reminderLabel = getReminderLabel(reminderDate, {fromNow: true})
    }

    return (
      <button
        tabIndex={-1}
        className={className}
        title={reminderLabel}
        onClick={this.onClick}
      >
        <RetinaImg name="icon-composer-reminders.png" mode={RetinaImg.Mode.ContentIsMask} />
        <span>&nbsp;</span>
        <RetinaImg name="icon-composer-dropdown.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );
  }
}

export default SendRemindersComposerButton
