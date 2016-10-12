{Utils, DraftStore, React, Actions, DatabaseStore, Contact, ReactDOM} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
Identity = require './identity'
ModalKeyRecommender = require './modal-key-recommender'
{RetinaImg} = require 'nylas-component-kit'
{remote} = require 'electron'
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
        # no key for this user
        keys.push(new Identity({addresses: [recipient.email]}))
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
    classnames = "btn btn-toolbar"
    if @state.currentlyEncrypted
      classnames += " btn-enabled"

    <div className="n1-keybase">
      <button title="Encrypt email body" className={ classnames } onClick={ => @_onClick()} ref="button">
        <RetinaImg url="nylas://keybase/encrypt-composer-button@2x.png" mode={RetinaImg.Mode.ContentIsMask} />
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
      identities = @_getKeys()
      @_checkKeysAndEncrypt(plaintext, identities, (err, cryptotext) =>
        if err
          console.warn err
          Actions.recordUserEvent("Email Encryption Errored", {error: err})
          NylasEnv.showErrorDialog(err)
        if cryptotext? and cryptotext != ""
          Actions.recordUserEvent("Email Encrypted")
          # <pre> tag prevents gross HTML formatting in-flight
          cryptotext = "<pre>#{cryptotext}</pre>"
          @setState({
            currentlyEncrypted: true
            plaintext: plaintext
            cryptotext: cryptotext
          })
          @props.session.changes.add({body: cryptotext})
      )

  _encrypt: (text, identities, cb) =>
    # get the actual key objects
    keys = _.pluck(identities, "key")
    # remove the nulls
    kms = _.compact(keys)
    if kms.length == 0
      NylasEnv.showErrorDialog("There are no PGP public keys loaded, so the message cannot be
       encrypted. Compose a message, add recipients in the To: field, and try again.")
      return
    params =
      encrypt_for: kms
      msg: text
    pgp.box(params, cb)

  _checkKeysAndEncrypt: (text, identities, cb) =>
    emails = _.chain(identities)
      .pluck("addresses")
      .flatten()
      .uniq()
      .value()

    if _.every(identities, (identity) -> identity.key?)
      # every key is present and valid
      @_encrypt(text, identities, cb)
    else
      # open a popover to correct null keys
      DatabaseStore.findAll(Contact, {email: emails}).then((contacts) =>
        component = (<ModalKeyRecommender contacts={contacts} emails={emails} callback={ (newIdentities) => @_encrypt(text, newIdentities, cb) }/>)
        Actions.openPopover(
          component,
        {
          originRect: ReactDOM.findDOMNode(@).getBoundingClientRect(),
          direction: 'up',
          closeOnAppBlur: false,
        })
      )

module.exports = EncryptMessageButton
