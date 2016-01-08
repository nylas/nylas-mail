{ComposerExtension, AccountStore} = require 'nylas-exports'

class SignatureComposerExtension extends ComposerExtension
  @prepareNewDraft: ({draft}) ->
    accountId = draft.accountId
    signature = NylasEnv.config.get("nylas.account-#{accountId}.signature")
    return unless signature

    insertionPoint = draft.body.indexOf('<blockquote')
    signatureHTML = '<div class="nylas-n1-signature">' + signature + '</div>'

    if insertionPoint is -1
      insertionPoint = draft.body.length
      signatureHTML = '<br/><br/>' + signatureHTML

    draft.body = draft.body.slice(0, insertionPoint) + signatureHTML + draft.body.slice(insertionPoint)

module.exports = SignatureComposerExtension
