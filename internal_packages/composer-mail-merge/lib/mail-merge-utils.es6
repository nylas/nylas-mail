import {Utils, Actions, Contact, DatabaseStore} from 'nylas-exports'
import {DataTransferTypes, ParticipantFields} from './mail-merge-constants'
import {mailMergeSessionForDraft} from './mail-merge-draft-editing-session'


export function contactFromColIdx(colIdx, email) {
  return new Contact({
    name: email || '',
    email: email || 'No value selected',
    clientId: `${DataTransferTypes.ColIdx}:${colIdx}`,
  })
}

export function colIdxFromContact(contact) {
  const {clientId} = contact
  if (!clientId.startsWith(DataTransferTypes.ColIdx)) {
    return null
  }
  return contact.clientId.split(':')[2]
}

export function bodyTokenRegex(draftClientId, colIdx) {
  // TODO update this regex for when it doesn't contain the style tag
  const reStr = `<span class="mail-merge-token" contenteditable="false" tabindex="-1" style="border: 1px solid red;" data-col-idx="${colIdx}" data-draft-client-id="${draftClientId}">[^]*</span>`
  return new RegExp(reStr)
}

function buildDraft(baseDraft, {sendData, linkedFields}) {
  const baseId = baseDraft.clientId
  const draftToSend = baseDraft.clone()
  draftToSend.clientId = Utils.generateTempId()

  // Replace tokens inside body with values from table data
  draftToSend.body = Array.from(linkedFields.body).reduce((currentBody, colIdx) => {
    const fieldValue = sendData[colIdx] || ""
    const wrappedValue = `<span>${fieldValue}</span>`
    return currentBody.replace(bodyTokenRegex(baseId, colIdx), wrappedValue)
  }, draftToSend.body)

  // Update participant values
  ParticipantFields.forEach((field) => {
    draftToSend[field] = Array.from(linkedFields[field]).map((colIdx) => {
      const value = sendData[colIdx] || ""
      return new Contact({name: value, email: value})
    })
  })
  return draftToSend
}

export function sendMassEmail(draftClientId) {
  const mailMergeSession = mailMergeSessionForDraft(draftClientId)
  if (!mailMergeSession) {
    return
  }

  // TODO If send later metadata is present on the base draft,
  // handle it correctly instead of sending immediately
  const baseDraft = mailMergeSession.draft()
  const {tableData: {rows}, linkedFields} = mailMergeSession.state

  const draftsData = rows.slice(1)
  const draftsToSend = draftsData.map((rowData) => (
    buildDraft(baseDraft, {sendData: rowData, linkedFields})
  ))
  Promise.all(
    draftsToSend.map((draft) => {
      return DatabaseStore.inTransaction((t) => {
        return t.persistModel(draft)
        .then(() => {
          Actions.sendDraft(draft.clientId)
        })
      })
    })
  )
}
