import React, {Component, PropTypes} from 'react'
import {RetinaImg} from 'nylas-component-kit'
import {sendMassEmail} from './mail-merge-utils'
import {mailMergeSessionForDraft} from './mail-merge-draft-editing-session'


class MailMergeSendButton extends Component {
  static displayName = 'MailMergeSendButton'

  static propTypes = {
    draft: PropTypes.object,
    session: PropTypes.object,
    isValidDraft: PropTypes.func,
    fallback: PropTypes.func,
  }

  constructor(props) {
    super(props)

    const {draftClientId, session} = props
    this.session = mailMergeSessionForDraft(draftClientId, session)
    this.state = {isWorkspaceOpen: this.session.state.isWorkspaceOpen}
  }

  componentDidMount() {
    this.session.listen(::this.onSessionChange)
  }

  onSessionChange() {
    this.setState({isWorkspaceOpen: this.session.state.isWorkspaceOpen})
  }

  onClick() {
    const {draft} = this.props
    sendMassEmail(draft.clientId)
  }

  primaryClick() {
    this.onClick()
  }

  render() {
    const {isWorkspaceOpen} = this.state
    if (!isWorkspaceOpen) {
      const Fallback = this.props.fallback
      return <Fallback {...this.props} />
    }

    return (
      <button
        tabIndex={-1}
        className={"btn btn-toolbar btn-normal btn-emphasis btn-text btn-send"}
        style={{order: -100}}
        onClick={::this.onClick}
      >
        <span>
          <RetinaImg
            name="icon-composer-send.png"
            mode={RetinaImg.Mode.ContentIsMask}
          />
          <span className="text">Send All</span>
        </span>
      </button>
    );
  }
}

MailMergeSendButton.containerRequired = false

export default MailMergeSendButton

