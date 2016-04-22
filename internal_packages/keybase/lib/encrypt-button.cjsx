{Utils, DraftStore, React} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
{RetinaImg} = require 'nylas-component-kit'
pgp = require 'kbpgp'
_ = require 'underscore'

class EncryptMessageButton extends React.Component

  @displayName: 'EncryptMessageButton'

  # require that we have a draft object available
  @propTypes:
    draft: React.PropTypes.object.isRequired
    session: React.PropTypes.object.isRequired

  constructor: (props) ->
    super(props)

    # plaintext: store the message's plaintext in case the user wants to edit
    # further after hitting the "encrypt" button (i.e. so we can "undo" the
    # encryption)

    # cryptotext: store the message's body here, for comparison purposes (so
    # that if the user edits an encrypted message, we can revert it)
    @state = {plaintext: "", cryptotext: "", currentlyEncrypted: false}

  componentDidMount: ->
    @unlistenKeystore = PGPKeyStore.listen(@_onKeystoreChange, @)

  componentWillUnmount: ->
    @unlistenKeystore()

  componentWillReceiveProps: (nextProps) ->
    if @state.currentlyEncrypted and nextProps.draft.body != @props.draft.body and nextProps.draft.body != @state.cryptotext
      # A) we're encrypted
      # B) someone changed something
      # C) the change was AWAY from the "correct" cryptotext
      body = @state.cryptotext
      @props.session.changes.add({body: body})

  _getKeys: ->
    keys = []
    for recipient in @props.draft.participants({includeFrom: false, includeBcc: true})
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

    return keys

  _onKeystoreChange: =>
    # if something changes with the keys, check to make sure the recipients
    # haven't changed (thus invalidating our encrypted message)
    if @state.currentlyEncrypted
      newKeys = _.map(@props.draft.participants(), (participant) ->
        return PGPKeyStore.pubKeys(participant.email)
      )
      newKeys = _.flatten(newKeys)

      oldKeys = _.map(@props.draft.participants(), (participant) ->
        return PGPKeyStore.pubKeys(participant.email)
      )
      oldKeys = _.flatten(oldKeys)

      if newKeys.length != oldKeys.length
        # someone added/removed a key - our encrypted body is now out of date
        @_toggleCrypt()

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
    # addresses which don't have a key
    if @state.currentlyEncrypted
      # if the message is already encrypted, place the stored plaintext back
      # in the draft (i.e. un-encrypt)
      @props.session.changes.add({body: @state.plaintext})
      @setState({currentlyEncrypted: false})
    else
      # if not encrypted, save the plaintext, then encrypt
      plaintext = @props.draft.body
      keys = @_getKeys()
      @_encrypt(plaintext, keys, (err, cryptotext) =>
        if err
          console.warn err
          NylasEnv.showErrorDialog(err)
        if cryptotext? and cryptotext != ""
          @setState({
            currentlyEncrypted: true
            plaintext: plaintext
            cryptotext: cryptotext
          })
          @props.session.changes.add({body: cryptotext})
      )

  _encrypt: (text, keys, cb) =>
    # addresses which don't have a key
    nullAddrs = _.pluck(_.filter(keys, (key) -> return key.key is null), "address")

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
    kms = _.compact(kms)
    params =
      encrypt_for: kms
      msg: text
    pgp.box(params, cb)

module.exports = EncryptMessageButton
