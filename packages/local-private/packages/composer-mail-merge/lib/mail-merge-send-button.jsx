import {remote} from 'electron'
import React, {Component, PropTypes} from 'react'
import {RetinaImg} from 'nylas-component-kit'
import {sendMailMerge} from './mail-merge-utils'
import ListensToMailMergeSession from './listens-to-mail-merge-session'


class MailMergeSendButton extends Component {
  static displayName = 'MailMergeSendButton'

  static containerRequired = false

  static propTypes = {
    draft: PropTypes.object,
    session: PropTypes.object,
    sessionState: PropTypes.object,
    isValidDraft: PropTypes.func,
    fallback: PropTypes.func,
  }

  constructor(props) {
    super(props)
    this.state = {
      sending: false,
    }
  }

  onClick = () => {
    const {sending} = this.state
    if (sending) { return }

    const {draft, isValidDraft} = this.props
    if (draft.to.length === 0) {
      const dialog = remote.dialog;
      dialog.showMessageBox(remote.getCurrentWindow(), {
        type: 'warning',
        buttons: ['Edit Message', 'Cancel'],
        message: 'Cannot Send',
        detail: "Before sending, you need to drag the header cell of the column of emails to the To field in Recipients",
      });
    } else {
      if (isValidDraft()) {
        this.setState({sending: true})
        try {
          sendMailMerge(draft.clientId)
        } catch (e) {
          this.setState({sending: false})
          NylasEnv.showErrorDialog(e.message)
        }
      }
    }
  }

  primarySend() {
    // Primary click is called when mod+enter is pressed.
    // If mail merge is not open, we should revert to default behavior
    const {isWorkspaceOpen} = this.props.sessionState
    if (!isWorkspaceOpen && this.refs.fallbackButton) {
      this.refs.fallbackButton.primarySend()
    } else {
      this.onClick()
    }
  }

  render() {
    const {sending} = this.state
    const {isWorkspaceOpen, tableDataSource} = this.props.sessionState
    if (!isWorkspaceOpen) {
      const Fallback = this.props.fallback
      return <Fallback ref="fallbackButton" {...this.props} />
    }

    const count = tableDataSource.rows().length
    const action = sending ? 'Sending' : 'Send'
    const sendLabel = count > 1 ? `${action} ${count} messages` : `${action} ${count} message`;
    let classes = "btn btn-toolbar btn-normal btn-emphasis btn-text btn-send"
    if (sending) {
      classes += " btn-disabled"
    }
    return (
      <button
        tabIndex={-1}
        className={classes}
        style={{order: -100}}
        onClick={this.onClick}
      >
        <span>
          <RetinaImg
            name="icon-composer-send.png"
            mode={RetinaImg.Mode.ContentIsMask}
          />
          <span className="text">{sendLabel}</span>
        </span>
      </button>
    );
  }
}

// TODO this is a hack so that the mail merge send button can still expose
// the `primarySend` method required by the ComposerView. Ideally, this
// decorator mechanism should expose whatever instance methods are exposed
// by the component its wrapping.
// However, I think the better fix will happen when mail merge lives in its
// own window and doesn't need to override the Composer's send button, which
// is already a bit of a hack.
const EnhancedMailMergeSendButton = ListensToMailMergeSession(MailMergeSendButton)
Object.assign(EnhancedMailMergeSendButton.prototype, {
  primarySend() {
    if (this.refs.composed) {
      this.refs.composed.primarySend()
    }
  },
})

export default EnhancedMailMergeSendButton
