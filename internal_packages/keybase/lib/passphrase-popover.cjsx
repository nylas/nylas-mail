{React, Actions} = require 'nylas-exports'
Identity = require './identity'
_ = require 'underscore'

module.exports =
class PassphrasePopover extends React.Component
  constructor: ->
    @state = {passphrase: ""}

  @propTypes:
    identity: React.PropTypes.instanceOf(Identity)

  render: ->
    passphrase = @state
    <div className="passphrase-popover">
      <input type="password" value={@state.passphrase} placeholder="PGP private key password" className="key-passphrase-input form-control" onChange={@_onPassphraseChange} />
      <button className="btn btn-toolbar" onClick={ @_onDone }>Done</button>
    </div>

  _onPassphraseChange: (event) =>
    @setState
      passphrase: event.target.value

  _onDone: =>
    if @props.identity?
      @props.onPopoverDone(@state.passphrase, @props.identity)
    else
      @props.onPopoverDone(@state.passphrase)
    Actions.closePopover()
