{DraftStoreExtension, AccountStore} = require 'nylas-exports'

class SignatureDraftStoreExtension extends DraftStoreExtension
  @prepareNewDraft: (draft) ->
    accountId = AccountStore.current().id
    signature = NylasEnv.config.get("nylas.account-#{accountId}.signature")
    return unless signature

    insertionPoint = draft.body.indexOf('<blockquote')
    if insertionPoint is -1
      insertionPoint = draft.body.length
    draft.body = draft.body.substr(0, insertionPoint-1) + signature + draft.body.substr(insertionPoint)

module.exports = SignatureDraftStoreExtension
