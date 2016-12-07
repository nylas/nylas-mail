
function collectFilesFromStruct({db, message, struct, fileIds = new Set()}) {
  const {File} = db;
  let collected = [];

  for (const part of struct) {
    if (part.constructor === Array) {
      collected = collected.concat(collectFilesFromStruct({db, message, struct: part, fileIds}));
    } else if (part.type !== 'text' && part.disposition) {
      // Only exposes partId for inline attachments
      const partId = part.disposition.type === 'inline' ? part.partID : null;
      const filename = part.disposition.params ? part.disposition.params.filename : null;
      const fileId = `${message.id}-${partId}-${part.size}`
      if (!fileIds.has(fileId)) {
        collected.push(File.build({
          id: fileId,
          partId: partId,
          size: part.size,
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

function extractFiles({db, message, imapMessage}) {
  const {attributes: {struct}} = imapMessage
  const files = collectFilesFromStruct({db, message, struct});
  if (files.length > 0) {
    return db.sequelize.transaction((transaction) =>
      Promise.all(files.map(f => f.save({transaction})))
    )
  }
  return Promise.resolve()
}

module.exports = extractFiles
