{React, Actions, AccountStore} = require 'nylas-exports'
{remote} = require 'electron'
Identity = require './identity'
PGPKeyStore = require './pgp-key-store'
PassphrasePopover = require './passphrase-popover'
_ = require 'underscore'
fs = require 'fs'
pgp = require 'kbpgp'

module.exports =
class PrivateKeyPopover extends React.Component
  constructor: ->
    @state = {
      selectedAddress: "0"
      keyBody: ""
      paste: false
      import: false
      validKeyBody: false
    }

  @propTypes:
    addresses: React.PropTypes.array

  render: =>
    errorBar = <div className="invalid-key-body">Invalid key body.</div>
    keyArea = <textarea value={@state.keyBody || ""} onChange={@_onKeyChange} placeholder="Paste in your PGP key here!"/>

    saveBtnClass = if !(@state.validKeyBody) then "btn modal-done-button btn-disabled" else "btn modal-done-button"
    saveButton = <button className={saveBtnClass} disabled={!(@state.validKeyBody)} onClick={@_onDone}>Save</button>

    <div className="private-key-popover" tabIndex=0>
      <span key="title" className="picker-title"><b>No PGP private key found.<br/>Add a key for {@_renderAddresses()}</b></span>
      <div className="key-add-buttons">
        <button className="btn btn-toolbar paste-btn" onClick={@_onClickPaste}>Paste in a Key</button>
        <button className="btn btn-toolbar import-btn" onClick={@_onClickImport}>Import from File</button>
      </div>
      {if (@state.import or @state.paste) and !@state.validKeyBody and @state.keyBody != "" then errorBar}
      {if @state.import or @state.paste then keyArea}
      <div className="picker-controls">
        <div style={{width: 80}}><button className="btn modal-cancel-button" onClick={=> Actions.closePopover()}>Cancel</button></div>
        <button className="btn modal-prefs-button" onClick={@_onClickAdvanced}>Advanced</button>
        <div style={{width: 80}}>{saveButton}</div>
      </div>
    </div>

  _renderAddresses: =>
    signedIn = _.pluck(AccountStore.accounts(), "emailAddress")
    suggestions = _.intersection(signedIn, @props.addresses)

    if suggestions.length == 1
      addresses = <span>{suggestions[0]}.</span>
    else if suggestions.length > 1
      options = suggestions.map((address) => <option value={suggestions.indexOf(address)} key={suggestions.indexOf(address)}>{address}</option>)
      addresses =
        <select value={@state.selectedAddress} onChange={@_onSelectAddress} style={{minWidth: 150}}>
          {options}
        </select>
    else
      throw new Error("How did you receive a message that you're not in the TO field for?")

  _onSelectAddress: (event) =>
    @setState
      selectedAddress: parseInt(event.target.value, 10)

  _displayError: (err) ->
    dialog = remote.dialog
    dialog.showErrorBox('Private Key Error', err.toString())

  _onClickAdvanced: =>
    Actions.switchPreferencesTab('Encryption')
    Actions.openPreferences()

  _onClickImport: (event) =>
    NylasEnv.showOpenDialog({
      title: "Import PGP Key",
      buttonLabel: "Import",
      properties: ['openFile']
    }, (filepath) =>
      if filepath?
        fs.readFile(filepath[0], (err, data) =>
          pgp.KeyManager.import_from_armored_pgp {
            armored: data
          }, (err, km) =>
            if err
              @_displayError("File is not a valid PGP private key.")
              return
            else
              privateStart = "-----BEGIN PGP PRIVATE KEY BLOCK-----"
              if km.armored_pgp_public.indexOf(privateStart) >= 0
                @setState
                  paste: false
                  import: true
                  keyBody: km.armored_pgp_public
                  validKeyBody: true
              else
                @_displayError("File is not a valid PGP private key.")
      )
    )

  _onClickPaste: (event) =>
    @setState
      paste: !@state.paste
      import: false
      keyBody: ""
      validKeyBody: false

  _onKeyChange: (event) =>
    @setState
      keyBody: event.target.value
    pgp.KeyManager.import_from_armored_pgp {
      armored: event.target.value
    }, (err, km) =>
      if err
        valid = false
      else
        privateStart = "-----BEGIN PGP PRIVATE KEY BLOCK-----"
        if km.armored_pgp_public.indexOf(privateStart) >= 0
          valid = true
        else
          valid = false
      @setState
        validKeyBody: valid

  _onDone: =>
    signedIn = _.pluck(AccountStore.accounts(), "emailAddress")
    suggestions = _.intersection(signedIn, @props.addresses)
    selectedAddress = suggestions[@state.selectedAddress]
    ident = new Identity({
      addresses: [selectedAddress]
      isPriv: true
    })
    @unlistenKeystore = PGPKeyStore.listen(@_onKeySaved, @)
    PGPKeyStore.saveNewKey(ident, @state.keyBody)

  _onKeySaved: =>
    @unlistenKeystore()
    Actions.closePopover()
    @props.callback()
