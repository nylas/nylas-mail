import Papa from 'papaparse'
import {
  Utils,
  Actions,
  Contact,
  RegExpUtils,
  DraftHelpers,
  DatabaseStore,
  SoundRegistry,
} from 'nylas-exports'

import {PLUGIN_ID, MAX_ROWS, DataTransferTypes, ParticipantFields} from './mail-merge-constants'
import {mailMergeSessionForDraft} from './mail-merge-draft-editing-session'
import SendManyDraftsTask from './send-many-drafts-task'


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

export function tokenQuerySelector(tokenId) {
  if (!tokenId) {
    return `img.mail-merge-token-wrap`
  }
  return `img.mail-merge-token-wrap[data-overlay-id="${tokenId}"]`
}

export function tokenRegex(tokenId) {
  if (!tokenId) {
    // https://regex101.com/r/sU7sO6/1
    return /<img[^>]*?class="[^>]*?mail-merge-token-wrap[^>]*?"[^>]*?>/gim
  }
  // https://regex101.com/r/fJ5eN6/5
  const reStr = `<img[^>]*?class="[^>]*?mail-merge-token-wrap[^>]*?" [^>]*?data-overlay-id="${tokenId}"[^>]*?>`
  return new RegExp(reStr, 'gim')
}

function replaceContenteditableTokens(html, {field, tableDataSource, tokenDataSource, rowIdx}) {
  const replaced = tokenDataSource.tokensForField(field)
  .reduce((currentHtml, {colIdx, tokenId}) => {
    const fieldValue = tableDataSource.cellAt({rowIdx, colIdx}) || ""
    const markup = `<span>${fieldValue}</span>`
    return currentHtml.replace(tokenRegex(tokenId), markup)
  }, html)
  if (tokenRegex().test(replaced)) {
    throw new Error(`Field ${field} still contains tokens after attempting to replace for table values`)
  }
  return replaced
}

export function buildDraft(baseDraft, {tableDataSource, tokenDataSource, rowIdx}) {
  if (tableDataSource.isEmpty({rowIdx})) {
    return null
  }
  const draftToSend = baseDraft.clone()
  draftToSend.clientId = Utils.generateTempId()

  // Clear any previous mail merge metadata on the draft we are going to send
  // and add rowIdx
  draftToSend.applyPluginMetadata(PLUGIN_ID, {rowIdx})

  // Replace tokens inside subject with values from table data
  const draftSubject = replaceContenteditableTokens(draftToSend.subject, {
    field: 'subject',
    rowIdx,
    tokenDataSource,
    tableDataSource,
  })
  draftToSend.subject = Utils.extractTextFromHtml(draftSubject)

  // Replace tokens inside body with values from table data
  draftToSend.body = replaceContenteditableTokens(draftToSend.body, {
    field: 'body',
    rowIdx,
    tokenDataSource,
    tableDataSource,
  })

  // Update participant values
  ParticipantFields.forEach((field) => {
    draftToSend[field] = tokenDataSource.tokensForField(field).map(({colIdx}) => {
      const column = tableDataSource.colAt(colIdx)
      const value = (tableDataSource.cellAt({rowIdx, colIdx}) || "").trim()
      const contact = new Contact({accountId: baseDraft.accountId, name: value, email: value})
      if (!contact.isValid()) {
        throw new Error(`Can't send messages:\nThe column ${column} contains an invalid email address at row ${rowIdx + 1}: "${value}"`)
      }
      return contact
    })
  })
  return draftToSend
}

export function sendManyDrafts(mailMergeSession, recipientDrafts) {
  const transformedDrafts = [];

  return mailMergeSession.draftSession().ensureCorrectAccount({noSyncback: true})
  .then(() => {
    const baseDraft = mailMergeSession.draft();
    return Promise.each(recipientDrafts, (recipientDraft) => {
      recipientDraft.accountId = baseDraft.accountId;
      recipientDraft.serverId = null;
      return DraftHelpers.applyExtensionTransforms(recipientDraft).then((transformed) =>
        transformedDrafts.push(transformed)
      );
    });
  })
  .then(() =>
    DatabaseStore.inTransaction(t => t.persistModels(transformedDrafts))
  )
  .then(async () => {
    const baseDraft = mailMergeSession.draft();

    if (baseDraft.uploads.length > 0) {
      recipientDrafts.forEach(async (d) => {
        await DraftHelpers.removeStaleUploads(d);
      })
    }

    const recipientClientIds = recipientDrafts.map(d => d.clientId)

    Actions.queueTask(new SendManyDraftsTask(baseDraft.clientId, recipientClientIds))

    if (NylasEnv.config.get("core.sending.sounds")) {
      SoundRegistry.playSound('hit-send');
    }
    NylasEnv.close();
  })
}

export function sendMailMerge(draftClientId) {
  const mailMergeSession = mailMergeSessionForDraft(draftClientId)
  if (!mailMergeSession) { return }

  const baseDraft = mailMergeSession.draft()
  const {tableDataSource, tokenDataSource} = mailMergeSession.state

  const recipientDrafts = tableDataSource.rows()
    .map((row, rowIdx) => (
      buildDraft(baseDraft, {tableDataSource, tokenDataSource, rowIdx})
    ))
    .filter((draft) => draft != null)

  if (recipientDrafts.length === 0) {
    NylasEnv.showErrorDialog(`There are no drafts to send! Add add some data to the table below`)
    return
  }
  sendManyDrafts(mailMergeSession, recipientDrafts)
}

export function parseCSV(file, maxRows = MAX_ROWS) {
  return new Promise((resolve, reject) => {
    Papa.parse(file, {
      skipEmptyLines: true,
      complete: ({data}) => {
        if (data.length === 0) {
          NylasEnv.showErrorDialog(
            `The csv file you are trying to import contains no rows. Please select another file.`
          );
          resolve(null)
          return;
        }

        // If a cell in the first row contains a valid email address, assume that
        // the table has no headers. We need row[0] to be field names, so make some up!
        const emailRegexp = RegExpUtils.emailRegex();
        const emailInFirstRow = data[0].find((val) => emailRegexp.test(val));
        if (emailInFirstRow) {
          const headers = data[0].map((val, idx) => {
            return emailInFirstRow === val ? 'Email Address' : `Column ${idx}`
          })
          data.unshift(headers);
        }

        const columns = data[0].slice()
        const rows = data.slice(1)
        if (rows.length > maxRows) {
          NylasEnv.showErrorDialog(
            `The csv file you are trying to import contains more than the max allowed number of rows (${maxRows}).\nWe have only imported the first ${maxRows} rows`
          );
          resolve({columns, rows: rows.slice(0, maxRows)})
          return
        }
        resolve({columns, rows})
      },
      error: (error) => {
        NylasEnv.showErrorDialog(`Sorry, we were unable to parse the file: ${file.name}\n${error.message}`);
        reject(error)
      },
    })
  })
}
