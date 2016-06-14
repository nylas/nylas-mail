{React, RegExpUtils} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
KeybaseSearch = require './keybase-search'
KeyManager = require './key-manager'
KeyAdder = require './key-adder'

class PreferencesKeybase extends React.Component
  @displayName: 'PreferencesKeybase'

  constructor: (@props) ->
    @_keySaveQueue = {}

    {pubKeys, privKeys} = @_getStateFromStores()
    @state =
      pubKeys: pubKeys
      privKeys: privKeys

  componentDidMount: =>
    @unlistenKeystore = PGPKeyStore.listen(@_onChange, @)

  componentWillUnmount: =>
    @unlistenKeystore()

  _onChange: =>
    @setState @_getStateFromStores()

  _getStateFromStores: ->
    pubKeys = PGPKeyStore.pubKeys()
    privKeys = PGPKeyStore.privKeys(timed: false)
    return {pubKeys, privKeys}

  render: =>
    noKeysMessage =
    <div className="key-status-bar no-keys-message">
      You have no saved PGP keys!
    </div>

    keyManager = <KeyManager pubKeys={@state.pubKeys} privKeys={@state.privKeys}/>

    <div className="container-keybase">
      <section className="key-add">
        <KeyAdder/>
      </section>
      <section className="keybase">
        <KeybaseSearch inPreferences={true} />
        {if @state.pubKeys.length == 0 and @state.privKeys.length == 0 then noKeysMessage else keyManager}
      </section>
    </div>

module.exports = PreferencesKeybase
