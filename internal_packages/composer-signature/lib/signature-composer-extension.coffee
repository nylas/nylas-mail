{ComposerExtension, AccountStore} = require 'nylas-exports'
SignatureUtils = require './signature-utils'

class SignatureComposerExtension extends ComposerExtension
  @prepareNewDraft: ({draft}) ->
    accountId = draft.accountId
    signature = NylasEnv.config.get("nylas.account-#{accountId}.signature")
    return unless signature

    draft.body = SignatureUtils.applySignature(draft.body, signature)

module.exports = SignatureComposerExtension
