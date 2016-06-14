{MessageStore, React, ReactDOM, FileDownloadStore, MessageBodyProcessor, Actions} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
PassphrasePopover = require './passphrase-popover'
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

  _onClickDecrypt: (event) =>
    popoverTarget = event.target.getBoundingClientRect()

    Actions.openPopover(
      <PassphrasePopover onPopoverDone={ @_decryptPopoverDone } />,
      {originRect: popoverTarget, direction: 'down'}
    )

  _onClickDecryptAttachments: (event) =>
    popoverTarget = event.target.getBoundingClientRect()

    Actions.openPopover(
      <PassphrasePopover onPopoverDone={ @_decryptAttachmentsPopoverDone } />,
      {originRect: popoverTarget, direction: 'down'}
    )

  _decryptPopoverDone: (passphrase) =>
    {message} = @props
    for recipient in message.to
      # right now, just try to unlock all possible keys
      # (many will fail - TODO?)
      privateKeys = PGPKeyStore.privKeys(address: recipient.email, timed: false)
      for privateKey in privateKeys
        PGPKeyStore.getKeyContents(key: privateKey, passphrase: passphrase)

  _decryptAttachmentsPopoverDone: (passphrase) =>
    {message} = @props
    for recipient in message.to
      privateKeys = PGPKeyStore.privKeys(address: recipient.email, timed: false)
      for privateKey in privateKeys
        PGPKeyStore.getKeyContents(key: privateKey, passphrase: passphrase, callback: (identity) => PGPKeyStore.decryptAttachments(identity, @state.encryptedAttachments))

  render: =>
    # TODO inform user of errors/etc. instead of failing without showing it
    if not (@state.wasEncrypted or @state.encryptedAttachments.length > 0)
      return false

    # TODO a message saying "this was decrypted with the key for ___@___.com"
    title = if @state.isDecrypted then "Message Decrypted" else "Message Encrypted"

    decryptBody = false
    if !@state.isDecrypted
      decryptBody = <button title="Decrypt email body" className="btn btn-toolbar" onClick={@_onClickDecrypt} ref="button">Decrypt</button>

    decryptAttachments = false
    if @state.encryptedAttachments?.length == 1
      decryptAttachments = <button onClick={ @_onClickDecryptAttachments } className="btn btn-toolbar">Decrypt Attachment</button>
      title = "Attachment Encrypted"
    else if @state.encryptedAttachments?.length > 1
      decryptAttachments = <button onClick={ @_onClickDecryptAttachments } className="btn btn-toolbar">Decrypt Attachments</button>
      title = "Attachments Encrypted"


    if decryptAttachments or decryptBody
      decryptionInterface = (<div className="decryption-interface">
        { decryptBody }
        { decryptAttachments }
      </div>)

    <div className="keybase-decrypt">
      <div className="line-w-label">
        <div className="border"></div>
          <div className="decrypt-bar">
            <div className="title-text">
              { title }
            </div>
            { decryptionInterface }
          </div>
        <div className="border"></div>
      </div>
    </div>

module.exports = DecryptMessageButton
