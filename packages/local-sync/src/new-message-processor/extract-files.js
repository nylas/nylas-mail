
function collectFilesFromStruct({db, message, struct}) {
  const {File} = db;
  let collected = [];

  for (const part of struct) {
    if (part.constructor === Array) {
      collected = collected.concat(collectFilesFromStruct({db, message, struct: part}));
    } else if (part.type !== 'text' && part.disposition) {
      // Only exposes partId for inline attachments
      const partId = part.disposition.type === 'inline' ? part.partID : null;
      const filename = part.disposition.params ? part.disposition.params.filename : null;
      collected.push(File.build({
        filename: filename,
        partId: partId,
        messageId: message.id,
        contentType: `${part.type}/${part.subtype}`,
        accountId: message.accountId,
        size: part.size,
        id: `${message.id}-${partId}-${part.size}`,
      }));
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
