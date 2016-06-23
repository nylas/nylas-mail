{MessageStore, React, ReactDOM, FileDownloadStore, MessageBodyProcessor, Actions} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
{remote} = require 'electron'
PassphrasePopover = require './passphrase-popover'
PrivateKeyPopover = require './private-key-popover'
pgp = require 'kbpgp'
_ = require 'underscore'

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
    {message} = @props
    popoverTarget = event.target.getBoundingClientRect()
    if @_noPrivateKeys()
      Actions.openPopover(
        <PrivateKeyPopover
          addresses={_.pluck(message.to, "email")}
          callback={() => @_openPassphrasePopover(popoverTarget, @decryptPopoverDone)}/>,
        {originRect: popoverTarget, direction: 'down'}
      )
    else
      @_openPassphrasePopover(popoverTarget, @decryptPopoverDone)

  _displayError: (err) ->
    dialog = remote.dialog
    dialog.showErrorBox('Decryption Error', err.toString())

  _onClickDecryptAttachments: (event) =>
    {message} = @props
    popoverTarget = event.target.getBoundingClientRect()
    if @_noPrivateKeys()
      Actions.openPopover(
        <PrivateKeyPopover
          addresses={_.pluck(message.to, "email")}
          callback={() => @_openPassphrasePopover(popoverTarget, @decryptAttachmentsPopoverDone)}/>,
        {originRect: popoverTarget, direction: 'down'}
      )
    else
      @_openPassphrasePopover(popoverTarget, @decryptAttachmentsPopoverDone)

  decryptPopoverDone: (passphrase) =>
    {message} = @props
    for recipient in message.to
      # right now, just try to unlock all possible keys
      # (many will fail - TODO?)
      privateKeys = PGPKeyStore.privKeys(address: recipient.email, timed: false)
      for privateKey in privateKeys
        PGPKeyStore.getKeyContents(key: privateKey, passphrase: passphrase)

  decryptAttachmentsPopoverDone: (passphrase) =>
    {message} = @props
    for recipient in message.to
      privateKeys = PGPKeyStore.privKeys(address: recipient.email, timed: false)
      for privateKey in privateKeys
        PGPKeyStore.getKeyContents(key: privateKey, passphrase: passphrase, callback: (identity) => PGPKeyStore.decryptAttachments(identity, @state.encryptedAttachments))

  _openPassphrasePopover: (target, callback) =>
    {message} = @props
    Actions.openPopover(
        <PassphrasePopover addresses={_.pluck(message.to, "email")} onPopoverDone={callback} />,
        {originRect: target, direction: 'down'}
      )

  _noPrivateKeys: =>
    {message} = @props
    numKeys = 0
    for recipient in message.to
      numKeys = numKeys + PGPKeyStore.privKeys(address: recipient.email, timed: false).length
    return numKeys < 1

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
