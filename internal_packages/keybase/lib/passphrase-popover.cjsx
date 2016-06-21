{React, Actions} = require 'nylas-exports'
Identity = require './identity'
PGPKeyStore = require './pgp-key-store'
_ = require 'underscore'
fs = require 'fs'
pgp = require 'kbpgp'

module.exports =
class PassphrasePopover extends React.Component
  constructor: ->
    @state = {
      passphrase: ""
      placeholder: "PGP private key password"
      classNames: "key-passphrase-input form-control"
    }

  @propTypes:
    identity: React.PropTypes.instanceOf(Identity)
    addresses: React.PropTypes.array

  render: ->
    <div className="passphrase-popover">
      <input type="password" value={@state.passphrase} placeholder={@state.placeholder} className={@state.classNames} onChange={@_onPassphraseChange} onKeyUp={@_onCarriageReturn} />
      <button className="btn btn-toolbar" onClick={@_validatePassphrase}>Done</button>
    </div>

  _onPassphraseChange: (event) =>
    @setState
      passphrase: event.target.value
      placeholder: "PGP private key password"
      classNames: "key-passphrase-input form-control"

  _onCarriageReturn: (event) =>
    if event.keyCode == 13
      @_validatePassphrase()

  _validatePassphrase: () =>
    passphrase = @state.passphrase
    for emailIndex of @props.addresses
      email = @props.addresses[emailIndex]
      privateKeys = PGPKeyStore.privKeys(address: email, timed: false)
      for keyIndex of privateKeys
        # check to see if the password unlocks the key
        key = privateKeys[keyIndex]
        fs.readFile(key.keyPath, (err, data) =>
          pgp.KeyManager.import_from_armored_pgp {
            armored: data
          }, (err, km) =>
            if err
              console.warn err
            else
              km.unlock_pgp { passphrase: passphrase }, (err) =>
                if err
                  if parseInt(keyIndex, 10) == privateKeys.length - 1
                    if parseInt(emailIndex, 10) == @props.addresses.length - 1
                      # every key has been tried, the password failed on all of them
                      @setState
                        passphrase: ""
                        placeholder: "Incorrect password"
                        classNames: "key-passphrase-input form-control bad-passphrase"
                else
                  # the password unlocked a key; that key should be used
                  @_onDone()
        )

  _onDone: =>
    if @props.identity?
      @props.onPopoverDone(@state.passphrase, @props.identity)
    else
      @props.onPopoverDone(@state.passphrase)
    Actions.closePopover()
