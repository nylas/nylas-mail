import React, {Component, PropTypes} from 'react'
import MailMergeWorkspace from './mail-merge-workspace'
import ListensToMailMergeSession from './listens-to-mail-merge-session'


class MailMergeContainer extends Component {
  static displayName = 'MailMergeContainer'

  static containerRequired = false

  static propTypes = {
    session: PropTypes.object,
    sessionState: PropTypes.object,
    draftClientId: PropTypes.string,
    mailMergeSession: PropTypes.object,
  }

  shouldComponentUpdate(nextProps) {
    // Make sure we only update if new state has been set
    // We do not care about our other props
    return (
      this.props.draftClientId !== nextProps.draftClientId ||
      this.props.sessionState !== nextProps.sessionState
    )
  }

  render() {
    const {draftClientId, sessionState, mailMergeSession} = this.props
    return (
      <MailMergeWorkspace
        {...sessionState}
        session={mailMergeSession}
        draftClientId={draftClientId}
      />
    )
  }
}

export default ListensToMailMergeSession(MailMergeContainer)
