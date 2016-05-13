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
    keys = @state.pubKeys
    # TODO private key management

    noKeysMessage =
    <div className="key-status-bar no-keys-message">
      You have no saved PGP keys!
    </div>

    <div>
      <section className="key-add">
        {if @state.pubKeys.length == 0 and @state.privKeys.length == 0 then noKeysMessage}
        <KeyAdder/>
      </section>
      <section className="keybase">
        <KeybaseSearch />
        <KeyManager keys={keys} />
      </section>
    </div>

module.exports = PreferencesKeybase
