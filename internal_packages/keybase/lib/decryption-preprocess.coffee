{MessageViewExtension, Actions} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'

class DecryptPGPExtension extends MessageViewExtension
  @formatMessageBody: ({message}) =>
    if not PGPKeyStore.hasEncryptedComponent(message)
      return message
    if PGPKeyStore.isDecrypted(message)
      message.body = PGPKeyStore.getDecrypted(message)
    else
      # trigger a decryption
      PGPKeyStore.decrypt(message)
    message

module.exports = DecryptPGPExtension
