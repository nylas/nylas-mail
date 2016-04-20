{Utils, DraftStore, React} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
{RetinaImg} = require 'nylas-component-kit'
pgp = require 'kbpgp'
_ = require 'underscore'

class EncryptMessageButton extends React.Component

  @displayName: 'EncryptMessageButton'

  # require that we have a draft object available
  @propTypes:
    draftClientId: React.PropTypes.string.isRequired

  constructor: (props) ->
    super(props)
    @state = @_getStateFromStores()

    # maintain the state of the button's toggle
    @state.currentlyEncrypted = false

    # store the message's plaintext in case the user wants to edit further after
    # hitting the "encrypt" button (i.e. so we can "undo" the encryption)
    @state.plaintext = ""

    # store the message's body here, for comparison purposes (so that if the
    # user edits an encrypted message, we can revert it)
    @state.cryptotext = ""

  componentDidMount: ->
    @unlistenKeystore = PGPKeyStore.listen(@_onKeystoreChange, @)
    # periodically check to see if we should get any keys
    @interval = setInterval(@_onTrigger, 100)

  componentWillUnmount: ->
    @unlistenKeystore()
    clearInterval(@interval)

  _getStateFromStores: ->
    keys = []
    DraftStore.sessionForClientId(@props.draftClientId).then (session) =>
      for recipient in session.draft().to
        publicKeys = PGPKeyStore.pubKeys(recipient.email)
        if publicKeys.length < 1
          # no key for this user:
          # push a null so that @_encrypt can line this array up with the
          # array of recipients
          keys.push({address: recipient.email, key: null})
        else
          # note: this, by default, encrypts using every public key associated
          # with the address
          for publicKey in publicKeys
            if not publicKey.key?
              PGPKeyStore.getKeyContents(key: publicKey)
            else
              keys.push(publicKey)

    return {
      keys: keys
    }

  _onKeystoreChange: =>
    if @state.currentlyEncrypted
      # message is no longer encrypted with all keys - decrypt it!
      @_toggleCrypt()
    # now actually get the new keys
    @setState(@_getStateFromStores())

  _onTrigger: =>
    # Some sort of outside event has occured that we must respond to
    DraftStore.sessionForClientId(@props.draftClientId).then (session) =>
      if @state.currentlyEncrypted
        # THERE CAN BE NO CHANGES
        if @state.cryptotext? and @state.cryptotext != ""
          # can't put HTML in or it will be sent with the message, confusing recipients
          #body = '<div style="background-color: #D3D3D3; padding: 10px;">' + @state.cryptotext + '</div>'
          body = @state.cryptotext
          session.changes.add({body: body})
      else
        plaintext = session.draft().body
        @setState({plaintext: plaintext})

    @setState(@_getStateFromStores())

  render: ->
    <div className="n1-keybase">
      <button title="Encrypt email body" className="btn btn-toolbar" onClick={ => @_onClick()} ref="button">
        Encrypt
      </button>
    </div>

  _onClick: =>
    @_toggleCrypt()

  _toggleCrypt: =>
    # if decrypted, encrypt, and vice versa
    DraftStore.sessionForClientId(@props.draftClientId).then (session) =>
      if @state.currentlyEncrypted
        # if the message is already encrypted, place the stored plaintext back
        # in the draft (i.e. un-encrypt)
        session.changes.add({body: @state.plaintext})
        @setState({currentlyEncrypted: false})
      else
        # if not encrypted, save the plaintext, then encrypt
        plaintext = session.draft().body
        @_encrypt(plaintext, @state.keys)
        @setState({currentlyEncrypted: true, plaintext: plaintext})

  _encrypt: (text, keys) =>
    # addresses which don't have a key
    nullAddrs = _.pluck(_.filter(@state.keys, (key) -> return key.key is null), "address")

    # don't need this, because the message below already says the recipient won't be able to decrypt it
    # if keys.length < 1 or nullAddrs.length == keys.length
    #   NylasEnv.showErrorDialog('This message is being encrypted with no keys - nobody will be able to decrypt it!')

    # get the actual key objects
    kms = _.pluck(keys, "key")

    if nullAddrs.length > 0
      missingAddrs = nullAddrs.join('\n- ')
      # TODO this message is annoying, needs some work
      # - link to preferences page
      # - formatting, probably an error dialog is the wrong way to do this
      # - potentially an option to disable this warning in the pref. page?
      NylasEnv.showErrorDialog("At least one key is missing - the following recipients won't be able to decrypt the message:\n- #{missingAddrs}\n\nYou can add keys for them from the preferences page.")

    # remove the nulls
    kms = _.reject(kms, (key) -> key == null)
    params =
      encrypt_for: kms
      msg: text
    pgp.box params, (err, result_string, result_buffer) =>
      if err
        console.warn err
      DraftStore.sessionForClientId(@props.draftClientId).then (session) =>
        # update state with the new encrypted text
        @setState({cryptotext: result_string})

module.exports = EncryptMessageButton
