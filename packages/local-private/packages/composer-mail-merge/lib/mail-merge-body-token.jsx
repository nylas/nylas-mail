import React, {Component, PropTypes} from 'react'
import MailMergeToken from './mail-merge-token'
import {DragBehaviors} from './mail-merge-constants'
import {tokenQuerySelector} from './mail-merge-utils'
import ListensToMailMergeSession from './listens-to-mail-merge-session'

/**
 * MailMergeBodyTokens are rendered by the OverlaidComponents component in the
 * subject and body of the composer.
 * The OverlaidComponents' state is effectively the state of the contenteditable
 * inside those fields, * and it decides what to render based on the
 * anchor (img) tags that are present in the contenteditable.
 *
 * Given this setup, we use the lifecycle methods of MailMergeBodyToken to keep
 * the state of the contenteditable (the tokens actually rendered in the UI),
 * in sync with our token state for mail merge (tokenDataSource)
 */
class MailMergeBodyToken extends Component {
  static displayName = 'MailMergeBodyToken'

  static propTypes = {
    className: PropTypes.string,
    tokenId: PropTypes.string,
    field: PropTypes.string,
    colName: PropTypes.string,
    sessionState: PropTypes.object,
    mailMergeSession: PropTypes.object,
    draftClientId: PropTypes.string,
    colIdx: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
    isPreview: PropTypes.bool,
  }

  constructor(props) {
    super(props)
    this.state = this.getState(props)
  }

  componentDidMount() {
    // When the token gets mounted, it means a mail merge token anchor node was
    // added to the contenteditable, via drop, paste, or any other means, so we
    // add it to our mail merge state
    const {colIdx, field, colName, tokenId, mailMergeSession} = this.props
    const {tokenDataSource} = mailMergeSession.state
    const token = tokenDataSource.getToken(field, tokenId)
    if (!token) {
      mailMergeSession.linkToDraft({colIdx, field, colName, tokenId})
    }
  }

  componentWillReceiveProps(nextProps) {
    this.setState(this.getState(nextProps, this.state.colIdx))
  }

  shouldComponentUpdate(nextProps, nextState) {
    return (
      this.props.isPreview !== nextProps.isPreview ||
      this.state.colIdx !== nextState.colIdx ||
      this.props.sessionState.selection !== nextProps.sessionState.selection ||
      this.props.sessionState.tableDataSource !== nextProps.sessionState.tableDataSource ||
      this.props.sessionState.tokenDataSource !== nextProps.sessionState.tokenDataSource
    )
  }

  componentDidUpdate() {
    // A token might be removed by mutations to the contenteditable, in which
    // case the tokenDataSource's state is updated by componentWillUnmount.
    //
    // However, when a token is removed from state via other means, e.g. when a
    // table column is removed, we also want to make sure that we remove it from the
    // UI. Since the contenteditable is effectively the source of state for
    // OverlaidComponents, we imperatively remove the token from contenteditable
    // if it has been removed from our state.
    const {field, tokenId, sessionState: {tokenDataSource}} = this.props
    const token = tokenDataSource.getToken(field, tokenId)
    if (!token) {
      const node = document.querySelector(tokenQuerySelector(tokenId))
      if (node) {
        node.parentNode.removeChild(node)
      }
    }
  }

  componentWillUnmount() {
    // A token might be removed by any sort of mutations to the contenteditable.
    // When an the actual anchor node in the contenteditable is removed from
    // the dom tree, OverlaidComponents will unmount our corresponding token,
    // so this is where we get to update our tokenDataSource's state
    const {field, tokenId, mailMergeSession} = this.props
    mailMergeSession.unlinkFromDraft({field, tokenId})
  }

  getState(props) {
    // Keep colIdx as state in case the column changes index when importing a
    // new csv file, thus changing styling
    const {sessionState: {tokenDataSource}, field, tokenId} = props
    const nextToken = tokenDataSource.getToken(field, tokenId)
    if (nextToken) {
      const {colIdx, colName} = nextToken
      return {colIdx, colName}
    }
    const {colIdx, colName} = props
    return {colIdx, colName}
  }

  render() {
    const {colIdx, colName} = this.state
    const {className, draftClientId, sessionState, isPreview} = this.props
    const {tableDataSource, selection} = sessionState
    const selectionValue = tableDataSource.cellAt({rowIdx: selection.rowIdx, colIdx}) || "No value selected"

    if (isPreview) {
      return <span>{selectionValue}</span>
    }

    return (
      <span className={className}>
        <MailMergeToken
          draggable
          colIdx={colIdx}
          colName={colName}
          dragBehavior={DragBehaviors.Move}
          draftClientId={draftClientId}
        >
          <span className="selection-value">
            {selectionValue}
          </span>
        </MailMergeToken>
      </span>
    )
  }
}
export default ListensToMailMergeSession(MailMergeBodyToken)
