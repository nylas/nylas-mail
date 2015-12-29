{ComposerExtension, AccountStore} = require 'nylas-exports'

class SignatureComposerExtension extends ComposerExtension
  @prepareNewDraft: (draft) ->
    accountId = AccountStore.current().id
    signature = NylasEnv.config.get("nylas.account-#{accountId}.signature")
    return unless signature

    insertionPoint = draft.body.indexOf('<blockquote')
    if insertionPoint is -1
      insertionPoint = draft.body.length
    draft.body = draft.body.slice(0, insertionPoint) + '<br/><div class="nylas-n1-signature">' + signature + "</div>" + draft.body.slice(insertionPoint)

module.exports = SignatureComposerExtension
