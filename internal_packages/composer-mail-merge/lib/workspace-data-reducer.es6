import _ from 'underscore'
import {contactFromColIdx} from './mail-merge-utils'
import {ParticipantFields} from './mail-merge-constants'


export function toDraft(draft, {tableData, selection, linkedFields}) {
  const contactsPerField = ParticipantFields.map((field) => (
    [...linkedFields[field]].map(colIdx => {
      const selectionValue = tableData.rows[selection.row][colIdx]
      return contactFromColIdx(colIdx, selectionValue)
    })
  ))
  return _.object(ParticipantFields, contactsPerField)
}

export function toJSON({linkedFields}) {
  return {
    linkedFields: {
      to: [...linkedFields.to],
      cc: [...linkedFields.cc],
      bcc: [...linkedFields.bcc],
      body: [...linkedFields.body],
    },
  }
}

export function fromJSON({linkedFields}) {
  return {
    linkedFields: {
      to: new Set(linkedFields.to),
      cc: new Set(linkedFields.cc),
      bcc: new Set(linkedFields.bcc),
      body: new Set(linkedFields.body),
    },
  }
}

export function initialState(savedData) {
  if (savedData && savedData.linkedFields) {
    return {
      isWorkspaceOpen: true,
      linkedFields: savedData.linkedFields,
    }
  }
  return {
    isWorkspaceOpen: false,
    linkedFields: {
      to: new Set(),
      cc: new Set(),
      bcc: new Set(),
      body: new Set(),
    },
  }
}

export function toggleWorkspace({isWorkspaceOpen}) {
  return {isWorkspaceOpen: !isWorkspaceOpen}
}

export function linkToDraft({linkedFields}, {colIdx, field}) {
  const linkedField = linkedFields[field]
  linkedField.add(colIdx)
  return {
    linkedFields: {
      ...linkedFields,
      [field]: linkedField,
    },
  }
}

export function unlinkFromDraft({linkedFields}, {colIdx, field}) {
  const linkedField = linkedFields[field]
  linkedField.delete(colIdx)
  return {
    linkedFields: {
      ...linkedFields,
      [field]: linkedField,
    },
  }
}
