import {Utils} from 'nylas-exports'
import {mailMergeSessionForDraft} from './mail-merge-draft-editing-session'
import {DataTransferTypes, DragBehaviors} from './mail-merge-constants'


function updateCursorPosition({editor, event}) {
  const {clientX, clientY} = event
  const range = document.caretRangeFromPoint(clientX, clientY);
  range.collapse()
  editor.select(range)
  return range
}

export function shouldAcceptDrop({event}) {
  const {dataTransfer} = event;
  return !!dataTransfer.getData(DataTransferTypes.ColIdx);
}

export function onDragOver({editor, event}) {
  updateCursorPosition({editor, event})
}

export function onDrop(field, {editor, event}) {
  const {dataTransfer} = event
  const colIdx = dataTransfer.getData(DataTransferTypes.ColIdx)
  const colName = dataTransfer.getData(DataTransferTypes.ColName)
  const dragBehavior = dataTransfer.getData(DataTransferTypes.DragBehavior)
  const draftClientId = dataTransfer.getData(DataTransferTypes.DraftId)
  const mailMergeSession = mailMergeSessionForDraft(draftClientId)
  if (!mailMergeSession) {
    return
  }

  if (dragBehavior === DragBehaviors.Move) {
    const {tokenDataSource} = mailMergeSession.state
    const {tokenId} = tokenDataSource.findTokens(field, {colName, colIdx}).pop() || {}
    editor.removeCustomComponentByAnchorId(tokenId)
  }

  updateCursorPosition({editor, event})
  const tokenId = Utils.generateTempId()
  editor.insertCustomComponent('MailMergeBodyToken', {
    field,
    colIdx,
    colName,
    tokenId,
    draftClientId,
    anchorId: tokenId,
    className: 'mail-merge-token-wrap',
  })
}
