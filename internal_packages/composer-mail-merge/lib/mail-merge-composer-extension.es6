import {mailMergeSessionForDraft} from './mail-merge-draft-editing-session'
import {DataTransferTypes} from './mail-merge-constants'


export const name = 'MailMergeComposerExtension'

function updateCursorPosition({editor, event}) {
  const {clientX, clientY} = event
  const range = document.caretRangeFromPoint(clientX, clientY);
  range.collapse()
  editor.select(range)
  return range
}

export function onDragOver({editor, event}) {
  updateCursorPosition({editor, event})
}

export function onDrop({editor, event}) {
  const {dataTransfer} = event
  const range = updateCursorPosition({editor, event})

  const colIdx = dataTransfer.getData(DataTransferTypes.ColIdx)
  const draftClientId = dataTransfer.getData(DataTransferTypes.DraftId)
  const mailMergeSession = mailMergeSessionForDraft(draftClientId)

  if (!mailMergeSession) {
    return
  }

  const newNode = document.createElement('span')
  newNode.setAttribute('class', 'mail-merge-token')
  newNode.setAttribute('contenteditable', false)
  newNode.setAttribute('tabindex', -1)
  newNode.setAttribute('style', 'border: 1px solid red;')
  newNode.setAttribute('data-col-idx', colIdx)
  newNode.setAttribute('data-draft-client-id', draftClientId)

  range.insertNode(newNode)
  mailMergeSession.linkToDraft({colIdx, field: 'body'})
}
