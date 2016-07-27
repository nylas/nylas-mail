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
    # every time a new key gets unlocked/fetched, try to decrypt this message
    if not @state.isDecrypted
      PGPKeyStore.decrypt(@props.message)
    @setState(@_getStateFromStores())

  _onClickDecrypt: (event) =>
    popoverTarget = event.target.getBoundingClientRect()
    if @_noPrivateKeys()
      Actions.openPopover(
        <PrivateKeyPopover
          addresses={_.pluck(@props.message.to, "email")}
          callback={=> @_openPassphrasePopover(popoverTarget, @decryptPopoverDone)}/>,
        {originRect: popoverTarget, direction: 'down'}
      )
    else
      @_openPassphrasePopover(popoverTarget, @decryptPopoverDone)

  _displayError: (err) ->
    dialog = remote.dialog
    dialog.showErrorBox('Decryption Error', err.toString())

  _onClickDecryptAttachments: (event) =>
    popoverTarget = event.target.getBoundingClientRect()
    if @_noPrivateKeys()
      Actions.openPopover(
        <PrivateKeyPopover
          addresses={_.pluck(@props.message.to, "email")}
          callback={=> @_openPassphrasePopover(popoverTarget, @decryptAttachmentsPopoverDone)}/>,
        {originRect: popoverTarget, direction: 'down'}
      )
    else
      @_openPassphrasePopover(popoverTarget, @decryptAttachmentsPopoverDone)

  decryptPopoverDone: (passphrase) =>
    for recipient in @props.message.to
      # right now, just try to unlock all possible keys
      # (many will fail - TODO?)
      privateKeys = PGPKeyStore.privKeys(address: recipient.email, timed: false)
      for privateKey in privateKeys
        PGPKeyStore.getKeyContents(key: privateKey, passphrase: passphrase)

  decryptAttachmentsPopoverDone: (passphrase) =>
    for recipient in @props.message.to
      privateKeys = PGPKeyStore.privKeys(address: recipient.email, timed: false)
      for privateKey in privateKeys
        PGPKeyStore.getKeyContents(key: privateKey, passphrase: passphrase, callback: (identity) => PGPKeyStore.decryptAttachments(identity, @state.encryptedAttachments))

  _openPassphrasePopover: (target, callback) =>
    Actions.openPopover(
      <PassphrasePopover addresses={_.pluck(@props.message.to, "email")} onPopoverDone={callback} />,
      {originRect: target, direction: 'down'}
    )

  _noPrivateKeys: =>
    numKeys = 0
    for recipient in @props.message.to
      numKeys = numKeys + PGPKeyStore.privKeys(address: recipient.email, timed: false).length
    return numKeys < 1

  render: =>
    if not (@state.wasEncrypted or @state.encryptedAttachments.length > 0)
      return false

    title = "Message Encrypted"
    decryptLabel = "Decrypt"
    borderClass = "border"
    decryptClass = "decrypt-bar"
    if @state.status?
      if @state.status.indexOf("Message decrypted") >= 0
        title = @state.status
        borderClass = "border done-border"
        decryptClass = "decrypt-bar done-decrypt-bar"
      else if @state.status.indexOf("Unable to decrypt message.") >= 0
        title = @state.status
        borderClass = "border error-border"
        decryptClass = "decrypt-bar error-decrypt-bar"
        decryptLabel = "Try Again"

    decryptBody = false
    if !@state.isDecrypted and !(@state.status?.indexOf("malformed") >= 0)
      decryptBody = <button title="Decrypt email body" className="btn btn-toolbar" onClick={@_onClickDecrypt} ref="button">{decryptLabel}</button>

    decryptAttachments = false
    if @state.encryptedAttachments?.length >= 1
      title = if @state.encryptedAttachments.length == 1 then "Attachment Encrypted" else "Attachments Encrypted"
      buttonLabel = if @state.encryptedAttachments.length == 1 then "Decrypt Attachment" else "Decrypt Attachments"
      decryptAttachments = <button onClick={ @_onClickDecryptAttachments } className="btn btn-toolbar">{buttonLabel}</button>

    if decryptAttachments or decryptBody
      decryptionInterface =
        <div className="decryption-interface">
          {decryptBody}
          {decryptAttachments}
        </div>

    <div className="keybase-decrypt">
      <div className="line-w-label">
        <div className={borderClass}></div>
        <div className={decryptClass}>
          <div className="title-text">
            {title}
          </div>
          {decryptionInterface}
        </div>
        <div className={borderClass}></div>
      </div>
    </div>

module.exports = DecryptMessageButton
