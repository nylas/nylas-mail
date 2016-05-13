{MessageStore, React, ReactDOM, FileDownloadStore, MessageBodyProcessor} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
pgp = require 'kbpgp'

class DecryptMessageButton extends React.Component

  @displayName: 'DecryptMessageButton'

  @propTypes:
    message: React.PropTypes.object.isRequired

  constructor: (props) ->
    super(props)
    @state = @_getStateFromStores()

  _getStateFromStores: ->
    return {
      isDecrypted: PGPKeyStore.isDecrypted(@props.message)
      wasEncrypted: PGPKeyStore.hasEncryptedComponent(@props.message)
      encryptedAttachments: PGPKeyStore.fetchEncryptedAttachments(@props.message)
      status: PGPKeyStore.msgStatus(@props.message)
    }

  componentDidMount: ->
    @unlistenKeystore = PGPKeyStore.listen(@_onKeystoreChange, @)

  componentWillUnmount: ->
    @unlistenKeystore()

  _onKeystoreChange: ->
    @setState(@_getStateFromStores())
    # every time a new key gets unlocked/fetched, try to decrypt this message
    if not @state.isDecrypted
      PGPKeyStore.decrypt(@props.message)

  render: =>
    # TODO inform user of errors/etc. instead of failing without showing it
    if not (@state.wasEncrypted or @state.encryptedAttachments.length > 0)
      return

    decryptBody = false
    if !@state.isDecrypted
      decryptBody = <button title="Decrypt email body" className="btn btn-toolbar" onClick={ => @_onClick()} ref="button">Decrypt</button>

    decryptAttachments = false
    if @state.encryptedAttachments?.length == 1
      decryptAttachments = <button onClick={ @_decryptAttachments } className="btn btn-toolbar">Decrypt Attachment</button>
    else if @state.encryptedAttachments?.length > 1
      decryptAttachments = <button onClick={ @_decryptAttachments } className="btn btn-toolbar">Decrypt Attachments</button>

    if decryptAttachments or decryptBody
      decryptionInterface = (<div className="decryption-interface">
        <input type="password" ref="passphrase" placeholder="Private key passphrase"></input>
        { decryptBody }
        { decryptAttachments }
      </div>)

    message = <div className="message" ref="message">{@state.status}</div>
    title = "Message Encrypted"
    if @state.isDecrypted
      # TODO a message saying "this was decrypted with the key for ___@___.com"
      #message = <div className="decrypted" ref="decrypted">{@state.status}</div>
      title = "Message Decrypted"
      message = null


    <div className="keybase-decrypt">
      { message }
      { decryptionInterface }
      <div className="line-w-label">
        <div className="border"></div>
        <div className="title-text">{ title }</div>
        <div className="border"></div>
      </div>
    </div>

  _onClick: =>
    {message} = @props
    passphrase = ReactDOM.findDOMNode(@refs.passphrase).value
    for recipient in message.to
      # right now, just try to unlock all possible keys
      # (many will fail - TODO?)
      privateKeys = PGPKeyStore.privKeys(address: recipient.email, timed: false)
      for privateKey in privateKeys
        PGPKeyStore.getKeyContents(key: privateKey, passphrase: passphrase)

  _decryptAttachments: =>
    @_onClick() # unlock keys
    PGPKeyStore.decryptAttachments(@state.encryptedAttachments)

module.exports = DecryptMessageButton
