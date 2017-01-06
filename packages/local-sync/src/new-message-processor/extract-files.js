
function collectFilesFromStruct({db, message, struct, fileIds = new Set()}) {
  const {File} = db;
  let collected = [];

  for (const part of struct) {
    if (part.constructor === Array) {
      collected = collected.concat(collectFilesFromStruct({db, message, struct: part, fileIds}));
    } else {
      const disposition = part.disposition || {}
      const isAttachment = /attachment/gi.test(disposition.type);

      if (!isAttachment) continue

      const partId = part.partID
      const filename = (disposition.params || {}).filename;
      const fileId = `${message.id}-${partId}-${part.size}`
      if (!fileIds.has(fileId)) {
        collected.push(File.build({
          id: fileId,
          size: part.size,
          partId: partId,
          encoding: part.encoding,
          filename: filename,
          messageId: message.id,
          accountId: message.accountId,
          contentType: `${part.type}/${part.subtype}`,
        }));
        fileIds.add(fileId)
      }
    }
  }

  return collected;
}

async function extractFiles({db, message, imapMessage}) {
  const {attributes: {struct}} = imapMessage
  const files = collectFilesFromStruct({db, message, struct});
  if (files.length > 0) {
    for (const file of files) {
      await file.save()
    }
  }
  return Promise.resolve()
}

module.exports = extractFiles
