import {contactFromColIdx} from './mail-merge-utils'
import TokenDataSource from './token-data-source'
import {LinkableFields, ContenteditableFields, ParticipantFields} from './mail-merge-constants'


export function toDraftChanges(draft, {tableDataSource, selection, tokenDataSource}) {
  // Save the participant fields to fake Contacts
  const participantChanges = {}
  ParticipantFields.forEach((field) => (
    participantChanges[field] = tokenDataSource.tokensForField(field).map(({colIdx}) => {
      const selectionValue = tableDataSource.cellAt({rowIdx: selection.rowIdx, colIdx}) || ""
      return contactFromColIdx(colIdx, selectionValue.trim())
    })
  ))

  // Save the body and subject if they haven't been saved yet
  // This is necessary because new tokens wont be saved to the contenteditable
  // unless the user directly mutates the body or subject
  const contenteditableChanges = {}
  ContenteditableFields.forEach((field) => {
    const node = document.querySelector(`.${field}-field [contenteditable]`)
    if (node) {
      const latestValue = node.innerHTML
      if (draft[field] !== latestValue) {
        contenteditableChanges[field] = latestValue
      }
    }
  })

  return {...participantChanges, ...contenteditableChanges}
}

export function toJSON({tokenDataSource}) {
  return {tokenDataSource: tokenDataSource.toJSON()}
}

export function fromJSON({tokenDataSource}) {
  return {tokenDataSource: TokenDataSource.fromJSON(tokenDataSource)}
}

export function initialState(savedData) {
  if (savedData && savedData.tokenDataSource) {
    return {
      tokenDataSource: savedData.tokenDataSource,
    }
  }
  const tokenDataSource = new TokenDataSource()
  return { tokenDataSource }
}

export function loadTableData({tokenDataSource}, {newTableData}) {
  const nextColumns = newTableData.columns
  let nextTokenDataSource = new TokenDataSource()

  // When loading table data, if the new table data contains columns with the same
  // name, make sure to keep those tokens in our state with the updated position
  // of the column
  LinkableFields.forEach((field) => {
    const currentTokens = tokenDataSource.tokensForField(field)
    currentTokens.forEach((link) => {
      const {colName, ...props} = link
      const newColIdx = nextColumns.indexOf(colName)
      if (newColIdx !== -1) {
        nextTokenDataSource = nextTokenDataSource.linkToken(field, {
          ...props,
          colName,
          colIdx: newColIdx,
        })
      }
    })
  })
  return {tokenDataSource: nextTokenDataSource}
}

export function linkToDraft({tokenDataSource}, args) {
  const {colIdx, colName, field, ...props} = args
  if (!field) { throw new Error('MailMerge: Must provide `field` to `linkToDraft`') }
  if (!colIdx) { throw new Error('MailMerge: Must provide `colIdx` to `linkToDraft`') }
  if (colName == null) { throw new Error('MailMerge: Must provide `colName` to `linkToDraft`') }
  return {
    tokenDataSource: tokenDataSource.linkToken(field, {colIdx, colName, ...props}),
  }
}

export function unlinkFromDraft({tokenDataSource}, {field, tokenId}) {
  if (!field) { throw new Error('MailMerge: Must provide `field` to `linkToDraft`') }
  if (!tokenId) { throw new Error('MailMerge: Must provide `tokenId` to `linkToDraft`') }
  return {
    tokenDataSource: tokenDataSource.unlinkToken(field, tokenId),
  }
}

export function removeLastColumn({tokenDataSource, tableDataSource}) {
  const colIdx = tableDataSource.columns().length - 1
  const colName = tableDataSource.colAt(colIdx)
  let nextTokenDataSource = tokenDataSource

  // Unlink any fields that where linked to the column that is being removed
  LinkableFields.forEach((field) => {
    const tokensToRemove = tokenDataSource.findTokens(field, {colName})
    nextTokenDataSource = tokensToRemove.reduce((prevTokenDataSource, {tokenId}) => {
      return prevTokenDataSource.unlinkToken(field, tokenId)
    }, nextTokenDataSource)
  })
  return {tokenDataSource: nextTokenDataSource}
}

export function updateCell({tokenDataSource, tableDataSource}, {colIdx, isHeader, value}) {
  if (!isHeader) { return {tokenDataSource} }
  const currentColName = tableDataSource.colAt(colIdx)
  let nextTokenDataSource = tokenDataSource

  // Update any tokens that referenced the column name that is being updated
  LinkableFields.forEach((field) => {
    const tokens = tokenDataSource.findTokens(field, {colName: currentColName})
    tokens.forEach(({tokenId}) => {
      nextTokenDataSource = nextTokenDataSource.updateToken(field, tokenId, {colName: value})
    })
  })
  return {tokenDataSource: nextTokenDataSource}
}

