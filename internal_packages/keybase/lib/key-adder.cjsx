{Utils, React, RegExpUtils} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
kb = require './keybase'
pgp = require 'kbpgp'
_ = require 'underscore'

module.exports =
class KeyAdder extends React.Component
  @displayName: 'KeyAdder'

  constructor: (props) ->
    @state =
      address: ""
      keyContents: ""
      passphrase: ""

      pubKey: false
      privKey: false
      generate: false

      validAddress: false
      validKeyBody: false

      placeholder: "Your generated public key will appear here. Share it with your friends!"

  _renderAddButtons: ->
    <div>
      Add a PGP Key:
      <button className="btn key-creation-button" title="Paste in a Public Key" onClick={@_onPastePubButtonClick}>Paste in a Public Key</button>
      <button className="btn key-creation-button" title="Paste in a Private Key" onClick={@_onPastePrivButtonClick}>Paste in a Private Key</button>
      <button className="btn key-creation-button" title="Generate a New Keypair" onClick={@_onGenerateButtonClick}>Generate a New Keypair</button>
    </div>

  _onPastePubButtonClick: (event) =>
    @setState
      pubKey: !@state.pubKey
      generate: false
      privKey: false
      address: ""
      keyContents: ""

  _onPastePrivButtonClick: (event) =>
    @setState
      pubKey: false
      generate: false
      privKey: !@state.privKey
      address: ""
      keyContents: ""
      passphrase: ""

  _onGenerateButtonClick: (event) =>
    @setState
      generate: !@state.generate
      pubKey: false
      privKey: false
      address: ""
      keyContents: ""
      passphrase: ""

  _onInnerGenerateButtonClick: (event) =>
    @_generateKeypair()

  _generateKeypair: =>
    @setState
      placeholder: "Generating your key now..."
    pgp.KeyManager.generate_rsa { userid : @state.address }, (err, km) =>
      km.sign {}, (err) =>
        if err
          console.warn(err)
        # todo: add passphrase input
        km.export_pgp_private {passphrase: @state.passphrase}, (err, pgp_private) =>
          # Remove trailing whitespace, if necessary.
          #if pgp_private.charAt(pgp_private.length - 1) != '-'
          #  pgp_private = pgp_private.slice(0, -1)
          PGPKeyStore.saveNewKey(@state.address, pgp_private, isPub = false)
        km.export_pgp_public {}, (err, pgp_public) =>
          # Remove trailing whitespace, if necessary.
          #if pgp_public.charAt(pgp_public.length - 1) != '-'
          #  pgp_public = pgp_public.slice(0, -1)
          PGPKeyStore.saveNewKey(@state.address, pgp_public, isPub = true)
          @setState
            keyContents: pgp_public
            placeholder: "Your generated public key will appear here. Share it with your friends!"

  _saveNewPubKey: =>
    PGPKeyStore.saveNewKey(@state.address, @state.keyContents, isPub = true)

  _saveNewPrivKey: =>
    PGPKeyStore.saveNewKey(@state.address, @state.keyContents, isPub = false)

  _onAddressChange: (event) =>
    address = event.target.value
    valid = false
    if (address and address.length > 0 and RegExpUtils.emailRegex().test(address))
      valid = true
    @setState
      address: event.target.value
      validAddress: valid

  _onPassphraseChange: (event) =>
    @setState
      passphrase: event.target.value

  _onKeyChange: (event) =>
    @setState
      keyContents: event.target.value
    pgp.KeyManager.import_from_armored_pgp {
      armored: event.target.value
    }, (err, km) =>
      if err
        console.warn(err)
        valid = false
      else
        valid = true
      @setState
        validKeyBody: valid

  _renderPasteKey: ->
    publicButton = <button className="btn key-add-btn" disabled={!(@state.validAddress & @state.validKeyBody)} title="Save" onClick={@_saveNewPubKey}>Save</button>
    privateButton = <button className="btn key-add-btn" disabled={!(@state.validAddress & @state.validKeyBody)} title="Save" onClick={@_saveNewPrivKey}>Save</button>

    passphraseInput = <input type="text" value={@state.passphrase} placeholder="Input a password for the private key." className="key-passphrase-input" onChange={@_onPassphraseChange} />

    <div className="key-adder">
      <div className="key-text">
        <textarea ref="key-input"
                value={@state.keyContents || ""}
                onChange={@_onKeyChange}
                placeholder="Paste in your PGP key here!"/>
      </div>
      <div>
        <input type="text" value={@state.address} placeholder="Which email address is this key for?" className="key-email-input" onChange={@_onAddressChange} />
        {if @state.privKey then passphraseInput}
        {if @state.privKey then privateButton}
        {if @state.pubKey then publicButton}
      </div>
    </div>

  _renderGenerateKey: ->
    <div className="key-adder">
      <div>
        <input type="text" value={@state.address} placeholder="Which email address is this key for?" className="key-email-input" onChange={@_onAddressChange} />
        <input type="text" value={@state.passphrase} placeholder="Input a password for the private key." className="key-passphrase-input" onChange={@_onPassphraseChange} />
        <button className="btn key-add-btn" disabled={!(@state.validAddress)} title="Generate" onClick={@_onInnerGenerateButtonClick}>Generate</button>
      </div>
      <div className="key-text">
        <textarea ref="key-output"
              value={@state.keyContents || ""}
              disabled
              placeholder={@state.placeholder}/>
      </div>
    </div>

  render: ->

    <div>
      {@_renderAddButtons()}
      {if @state.generate then @_renderGenerateKey()}
      {if @state.pubKey or @state.privKey then @_renderPasteKey()}
    </div>
