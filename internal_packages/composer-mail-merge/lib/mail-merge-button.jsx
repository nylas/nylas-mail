import React, {Component, PropTypes} from 'react'
import {mailMergeSessionForDraft} from './mail-merge-draft-editing-session'


class MailMergeButton extends Component {
  static displayName = 'MailMergeButton'

  static propTypes = {
    session: PropTypes.object,
    draftClientId: PropTypes.string,
  }

  constructor(props) {
    super(props)

    const {draftClientId, session} = props
    this.session = mailMergeSessionForDraft(draftClientId, session)
  }

  render() {
    return (
      <div className="btn btn-small" onClick={this.session.toggleWorkspace}>Merge</div>
    )
  }
}

export default MailMergeButton
