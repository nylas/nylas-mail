{DraftStoreExtension, NamespaceStore} = require 'nylas-exports'

class SignatureDraftStoreExtension extends DraftStoreExtension
  @prepareNewDraft: (draft) ->
    namespaceId = NamespaceStore.current().id
    signature = atom.config.get("signatures.#{namespaceId}")
    return unless signature

    insertionPoint = draft.body.indexOf('<blockquote')
    if insertionPoint is -1
      insertionPoint = draft.body.length
    draft.body = draft.body.substr(0, insertionPoint-1) + signature + draft.body.substr(insertionPoint)

module.exports = SignatureDraftStoreExtension
