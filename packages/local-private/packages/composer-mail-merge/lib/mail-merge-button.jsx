import classnames from 'classnames'
import React, {PropTypes} from 'react'
import {RetinaImg} from 'nylas-component-kit'
import ListensToMailMergeSession from './listens-to-mail-merge-session'


function MailMergeButton(props) {
  if (props.draft.replyToMessageId) {
    return <span />;
  }

  const {mailMergeSession, sessionState} = props
  const {isWorkspaceOpen} = sessionState
  const classes = classnames({
    "btn": true,
    "btn-toolbar": true,
    "btn-enabled": isWorkspaceOpen,
    "btn-mail-merge": true,
  })

  return (
    <button
      className={classes}
      title="Mass Email"
      onClick={mailMergeSession.toggleWorkspace}
      tabIndex={-1}
      style={{order: -99}}
    >
      <RetinaImg
        name="icon-composer-mailmerge.png"
        mode={RetinaImg.Mode.ContentIsMask}
      />
    </button>
  )
}
MailMergeButton.displayName = 'MailMergeButton'
MailMergeButton.containerRequired = false
MailMergeButton.propTypes = {
  draft: PropTypes.object,
  session: PropTypes.object,
  sessionState: PropTypes.object,
  draftClientId: PropTypes.string,
  mailMergeSession: PropTypes.object,
}

export default ListensToMailMergeSession(MailMergeButton)
