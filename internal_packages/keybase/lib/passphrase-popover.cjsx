{React, Actions} = require 'nylas-exports'
Identity = require './identity'
_ = require 'underscore'

module.exports =
class PassphrasePopover extends React.Component
  constructor: ->
    @state = {passphrase: ""}

  @propTypes:
    identity: React.PropTypes.instanceOf(Identity).isRequired

  render: ->
    passphrase = @state

    <div className="keybase-import-popover">
      <span className="title">
        Enter Password for Private Key
      </span>
      <input type="password" value={@state.passphrase} className="key-passphrase-input" onChange={@_onPassphraseChange} />
      <button className="btn btn-toolbar" onClick={ @_onDone }>Done</button>
    </div>

  _onPassphraseChange: (event) =>
    @setState
      passphrase: event.target.value

  _onDone: =>
    @props.onPopoverDone(@props.identity, @state.passphrase)
    Actions.closePopover()
