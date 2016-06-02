{Utils, React, RegExpUtils} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
Identity = require './identity'
kb = require './keybase'
pgp = require 'kbpgp'
_ = require 'underscore'
fs = require 'fs'

module.exports =
class KeyAdder extends React.Component
  @displayName: 'KeyAdder'

  constructor: (props) ->
    @state =
      address: ""
      keyContents: ""
      passphrase: ""

      generate: false
      paste: false
      import: false

      isPriv: false

      validAddress: false
      validKeyBody: false

      placeholder: "Your generated public key will appear here. Share it with your friends!"

  _onPasteButtonClick: (event) =>
    @setState
      generate: false
      paste: !@state.paste
      import: false
      address: ""
      keyContents: ""

  _onGenerateButtonClick: (event) =>
    @setState
      generate: !@state.generate
      paste: false
      import: false
      address: ""
      keyContents: ""
      passphrase: ""

  _onImportButtonClick: (event) =>
    NylasEnv.showOpenDialog({
        title: "Import PGP Key",
        buttonLabel: "Import",
        properties: ['openFile']
      }, (filepath) =>
        if filepath?
          @setState
            generate: false
            paste: false
            import: true
            address: ""
            passphrase: ""
          fs.readFile(filepath[0], (err, data) =>
            pgp.KeyManager.import_from_armored_pgp {
              armored: data
            }, (err, km) =>
              if err
                PGPKeyStore._displayError("The file you selected for import is not a valid PGP Key.")
                return
              else
                privateStart = "-----BEGIN PGP PRIVATE KEY BLOCK-----"
                keyBody = if km.armored_pgp_private? then km.armored_pgp_private else km.armored_pgp_public
                @setState
                  keyContents: keyBody
                  isPriv: keyBody.indexOf(privateStart) >= 0
                  validKeyBody: true
        )
    )

  _onInnerGenerateButtonClick: (event) =>
    @_generateKeypair()

  _generateKeypair: =>
    @setState
      placeholder: "Generating your key now..."
    pgp.KeyManager.generate_rsa { userid : @state.address }, (err, km) =>
      km.sign {}, (err) =>
        if err
          console.warn(err)
        km.export_pgp_private {passphrase: @state.passphrase}, (err, pgp_private) =>
          ident = new Identity({
            addresses: [@state.address]
            isPriv: true
          })
          PGPKeyStore.saveNewKey(ident, pgp_private)
        km.export_pgp_public {}, (err, pgp_public) =>
          ident = new Identity({
            addresses: [@state.address]
            isPriv: false
          })
          PGPKeyStore.saveNewKey(ident, pgp_public)
          @setState
            keyContents: pgp_public
            placeholder: "Your generated public key will appear here. Share it with your friends!"

  _saveNewKey: =>
    ident = new Identity({
      addresses: [@state.address]
      isPriv: @state.isPriv
    })
    PGPKeyStore.saveNewKey(ident, @state.keyContents)

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
    privateStart = "-----BEGIN PGP PRIVATE KEY BLOCK-----"
    @setState
      keyContents: event.target.value
      isPriv: event.target.value.indexOf(privateStart) >= 0
    pgp.KeyManager.import_from_armored_pgp {
      armored: event.target.value
    }, (err, km) =>
      if err
        valid = false
      else
        valid = true
      @setState
        validKeyBody: valid

  _renderAddButtons: ->
    <div>
      Add a PGP Key:
      <button className="btn key-creation-button" title="Paste" onClick={@_onPasteButtonClick}>Paste in a New Key</button>
      <button className="btn key-creation-button" title="Import" onClick={@_onImportButtonClick}>Import a Key From File</button>
      <button className="btn key-creation-button" title="Generate" onClick={@_onGenerateButtonClick}>Generate a New Keypair</button>
    </div>

  _renderManualKey: ->
    invalidInputs = !(@state.validAddress & @state.validKeyBody)
    buttonClass = if invalidInputs then "btn key-add-btn btn-disabled" else "btn key-add-btn"

    passphraseInput = <input type="password" value={@state.passphrase} placeholder="Input a password for the private key." className="key-passphrase-input" onChange={@_onPassphraseChange} />

    <div className="key-adder">
      <div className="key-text">
        <textarea ref="key-input"
                value={@state.keyContents || ""}
                onChange={@_onKeyChange}
                placeholder="Paste in your PGP key here!"/>
      </div>
      <div>
        <input type="text" value={@state.address} placeholder="Which email address is this key for?" className="key-email-input" onChange={@_onAddressChange} />
        {if @state.isPriv then passphraseInput}
        <button className={buttonClass} disabled={invalidInputs} title="Save" onClick={@_saveNewKey}>Save</button>
      </div>
    </div>

  _renderGenerateKey: ->
    <div className="key-adder">
      <div>
        <input type="text" value={@state.address} placeholder="Which email address is this key for?" className="key-email-input" onChange={@_onAddressChange} />
        <input type="password" value={@state.passphrase} placeholder="Input a password for the private key." className="key-passphrase-input" onChange={@_onPassphraseChange} />
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
      {if @state.paste or @state.import then @_renderManualKey()}
    </div>
