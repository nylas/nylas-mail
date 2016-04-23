import React, {Component, PropTypes} from 'react'
import MailMergeWorkspace from './mail-merge-workspace'
import {mailMergeSessionForDraft} from './mail-merge-draft-editing-session'


class MailMergeContainer extends Component {
  static displayName = 'MailMergeContainer'

  static propTypes = {
    draftClientId: PropTypes.string,
    session: PropTypes.object,
  }

  constructor(props) {
    super(props)

    const {draftClientId, session} = props
    this.unsubscribers = []
    this.session = mailMergeSessionForDraft(draftClientId, session)
    this.state = this.session.state
  }

  componentDidMount() {
    this.unsubscribers = [
      this.session.listen(::this.onSessionChange),
    ]
  }

  shouldComponentUpdate(nextProps, nextState) {
    // Make sure we only update if new state has been set
    // We do not care about our other props
    return (
      this.props.draftClientId !== nextProps.draftClientId ||
      this.state !== nextState
    )
  }

  componentWillUnmount() {
    this.unsubscribers.forEach(unsub => unsub())
  }

  onSessionChange() {
    this.setState(this.session.state)
    // Nasty side effects
    this.updateComposerBody(this.session.state)
  }

  updateComposerBody({tableData, selection, linkedFields}) {
    // TODO I don't want to reach into the DOM :(
    const {rows} = tableData
    const {draftClientId} = this.props

    linkedFields.body.forEach((colIdx) => {
      const selector = `[contenteditable] .mail-merge-token[data-col-idx="${colIdx}"][data-draft-client-id="${draftClientId}"]`
      const nodes = Array.from(document.querySelectorAll(selector))
      const selectionValue = rows[selection.row][colIdx] || "No value selected"
      nodes.forEach(node => { node.innerText = selectionValue })
    })
  }

  render() {
    const {draftClientId} = this.props
    return (
      <MailMergeWorkspace
        {...this.state}
        session={this.session}
        draftClientId={draftClientId}
      />
    )
  }
}
MailMergeContainer.containerRequired = false

export default MailMergeContainer
