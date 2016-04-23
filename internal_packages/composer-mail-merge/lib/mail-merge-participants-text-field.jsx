import React, {Component, PropTypes} from 'react';
import classnames from 'classnames'
import {RegExpUtils} from 'nylas-exports'
import {DropZone, TokenizingTextField} from 'nylas-component-kit'
import {DataTransferTypes} from './mail-merge-constants'
import {mailMergeSessionForDraft} from './mail-merge-draft-editing-session'


class MailMergeParticipantToken extends Component {
  static propTypes = {
    token: PropTypes.shape({
      selectionValue: PropTypes.any,
    }),
  }

  render() {
    const {token: {selectionValue}} = this.props
    if (!selectionValue) {
      return <span>No value selected</span>
    }
    return <span>{selectionValue}</span>
  }
}


class MailMergeParticipantsTextField extends Component {
  static displayName = 'MailMergeParticipantsTextField'

  static propTypes = {
    className: PropTypes.string,
    field: PropTypes.string,
    session: PropTypes.object,
    draftClientId: PropTypes.string,
    onAdd: PropTypes.func,
    onRemove: PropTypes.func,
  }

  static defaultProps = {
    className: '',
  }

  constructor(props) {
    super(props)
    this.session = mailMergeSessionForDraft(props.draftClientId, props.session)
    this.state = {isDropping: false, ...this.session.state}
  }

  componentDidMount() {
    this.unsubscribers = [
      this.session.listen(::this.onSessionChange),
    ]
  }

  componentWillUnmount() {
    this.unsubscribers.forEach(unsub => unsub())
  }

  // Called when a token is dragged and dropped in a new field
  onAddToken(...args) {
    const tokenToAdd = args[0][0]
    if (args.length > 1 || !tokenToAdd) { return }

    const {field} = this.props
    const {colIdx} = tokenToAdd
    this.session.unlinkFromDraft({colIdx, field: tokenToAdd.field})
    this.session.linkToDraft({colIdx, field})
  }

  onRemoveToken([tokenToDelete]) {
    const {field} = this.props
    const {colIdx} = tokenToDelete
    this.session.unlinkFromDraft({colIdx, field})
  }

  onDrop(event) {
    const {dataTransfer} = event
    const {field} = this.props
    const colIdx = dataTransfer.getData(DataTransferTypes.ColIdx)
    this.session.linkToDraft({colIdx, field})
  }

  onSessionChange() {
    this.setState(this.session.state)
  }

  onDragStateChange({isDropping}) {
    this.setState({isDropping})
  }

  tokenIsValid({selectionValue}) {
    return (
      selectionValue &&
      selectionValue.match(RegExpUtils.emailRegex()) != null
    )
  }

  focus() {
    this.refs.textField.focus()
  }

  shouldAcceptDrop(event) {
    const {dataTransfer} = event
    return !!dataTransfer.getData(DataTransferTypes.ColIdx)
  }

  render() {
    const {field, className} = this.props
    const {isWorkspaceOpen, tableData: {rows}, selection, linkedFields, isDropping} = this.state

    if (!isWorkspaceOpen) {
      return <TokenizingTextField ref="textField" {...this.props} />
    }

    const classes = classnames({
      'mail-merge-participants-text-field': true,
      'is-dropping': isDropping,
      [className]: true,
    })
    const tokens = (
      Array.from(linkedFields[field])
      .map(colIdx => ({field, colIdx, selectionValue: rows[selection.row][colIdx]}))
    )

    return (
      <DropZone
        onDrop={::this.onDrop}
        onDragStateChange={::this.onDragStateChange}
        shouldAcceptDrop={::this.shouldAcceptDrop}
      >
        <TokenizingTextField
          {...this.props}
          ref="textField"
          className={classes}
          tokens={tokens}
          tokenKey={(f) => `${f.colIdx}-${f.field}`}
          tokenRenderer={MailMergeParticipantToken}
          tokenIsValid={::this.tokenIsValid}
          onRequestCompletions={() => []}
          completionNode={() => <span />}
          onAdd={::this.onAddToken}
          onRemove={::this.onRemoveToken}
        />
      </DropZone>
    )
  }
}
MailMergeParticipantsTextField.containerRequired = false

export default MailMergeParticipantsTextField
