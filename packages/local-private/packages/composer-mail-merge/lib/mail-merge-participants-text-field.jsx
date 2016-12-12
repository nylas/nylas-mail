import React, {Component, PropTypes} from 'react';
import classnames from 'classnames'
import {DropZone, TokenizingTextField} from 'nylas-component-kit'
import MailMergeToken from './mail-merge-token'
import {DataTransferTypes} from './mail-merge-constants'
import ListensToMailMergeSession from './listens-to-mail-merge-session'


function MailMergeParticipantToken(props) {
  const {token: {tableDataSource, rowIdx, colIdx, colName}} = props
  const selectionValue = tableDataSource.cellAt({rowIdx, colIdx}) || 'No value selected'

  return (
    <MailMergeToken draggable colIdx={colIdx} colName={colName}>
      <span>{selectionValue}</span>
    </MailMergeToken>
  )
}
MailMergeParticipantToken.propTypes = {
  token: PropTypes.shape({
    colIdx: PropTypes.any,
    rowIdx: PropTypes.any,
    tableDataSource: PropTypes.object,
  }),
}


class MailMergeParticipantsTextField extends Component {
  static displayName = 'MailMergeParticipantsTextField'

  static containerRequired = false

  static propTypes = {
    onAdd: PropTypes.func,
    onRemove: PropTypes.func,
    field: PropTypes.string,
    session: PropTypes.object,
    className: PropTypes.string,
    sessionState: PropTypes.object,
    draftClientId: PropTypes.string,
    mailMergeSession: PropTypes.object,
  }

  static defaultProps = {
    className: '',
  }

  constructor(props) {
    super(props)
    this._tokenWasMovedBetweenFields = false
  }

  // This is called by the TokenizingTextField when a token is dragged and dropped
  // between fields
  onAddToken = (...args) => {
    const tokenToAdd = args[0][0]
    if (args.length > 1 || !tokenToAdd) { return }

    const {mailMergeSession} = this.props
    const {colIdx, colName, tokenId, field} = tokenToAdd
    // Remove from previous field
    mailMergeSession.unlinkFromDraft({field, tokenId})
    // Add to our current field
    mailMergeSession.linkToDraft({colIdx, colName, field: this.props.field})
    this._tokenWasMovedBetweenFields = true
  }

  onRemoveToken = ([tokenToDelete]) => {
    const {field, mailMergeSession} = this.props
    const {tokenId} = tokenToDelete
    mailMergeSession.unlinkFromDraft({field, tokenId})
  }

  onDrop = (event) => {
    if (this._tokenWasMovedBetweenFields) {
      // Ignore drop if we already added the token
      this._tokenWasMovedBetweenFields = false
      return
    }
    const {dataTransfer} = event
    const {field, mailMergeSession} = this.props
    const colIdx = dataTransfer.getData(DataTransferTypes.ColIdx)
    const colName = dataTransfer.getData(DataTransferTypes.ColName)
    mailMergeSession.linkToDraft({colIdx, colName, field})
  }

  focus() {
    this.refs.textField.focus()
  }

  shouldAcceptDrop = (event) => {
    const {dataTransfer} = event
    return !!dataTransfer.getData(DataTransferTypes.ColIdx)
  }

  render() {
    const {field, className, sessionState} = this.props
    const {isWorkspaceOpen, tableDataSource, selection, tokenDataSource} = sessionState

    if (!isWorkspaceOpen) {
      return <TokenizingTextField ref="textField" {...this.props} />
    }

    const classes = classnames({
      'mail-merge-participants-text-field': true,
      [className]: true,
    })
    const tokens = (
      tokenDataSource.tokensForField(field)
      .map((token) => ({...token, tableDataSource, rowIdx: selection.rowIdx}))
    )

    return (
      <DropZone
        onDrop={this.onDrop}
        shouldAcceptDrop={this.shouldAcceptDrop}
      >
        <TokenizingTextField
          {...this.props}
          ref="textField"
          className={classes}
          tokens={tokens}
          tokenKey={(token) => token.tokenId}
          tokenRenderer={MailMergeParticipantToken}
          tokenIsValid={() => true}
          tokenClassNames={(token) => `token-color-${token.colIdx % 5}`}
          onRequestCompletions={() => []}
          completionNode={() => <span />}
          onAdd={this.onAddToken}
          onRemove={this.onRemoveToken}
          onTokenAction={false}
        />
      </DropZone>
    )
  }
}

export default ListensToMailMergeSession(MailMergeParticipantsTextField)
