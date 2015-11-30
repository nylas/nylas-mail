React = require 'react'
_ = require 'underscore'
{Contenteditable, RetinaImg, Flexbox} = require 'nylas-component-kit'
{AccountStore, Utils} = require 'nylas-exports'

class PreferencesSignatures extends React.Component
  @displayName: 'PreferencesSignatures'

  constructor: (@props) ->
    @_signatureSaveQueue = {}

    selectedAccountId = AccountStore.current()?.id
    if selectedAccountId
      key = @_configKey(selectedAccountId)
      initialSig = @props.config.get(key)
    else
      initialSig = ""

    @state =
      accounts: AccountStore.items()
      currentSignature: initialSig
      selectedAccountId: selectedAccountId

  componentDidMount: ->
    @usub = AccountStore.listen @_onChange

  shouldComponentUpdate: (nextProps, nextState) =>
    nextState.selectedAccountId isnt @state.selectedAccountId

  componentWillUnmount: ->
    @usub()
    @_saveSignatureNow(@state.selectedAccountId, @state.currentSignature)

  _saveSignatureNow: (accountId, value) =>
    key = @_configKey(accountId)
    @props.config.set(key, value)

  _saveSignatureSoon: (accountId, value) =>
    @_signatureSaveQueue[accountId] = value
    @_saveSignaturesFromCache()

  __saveSignaturesFromCache: =>
    for accountId, value of @_signatureSaveQueue
      @_saveSignatureNow(accountId, value)

    @_signatureSaveQueue = {}

  _saveSignaturesFromCache: _.debounce(PreferencesSignatures::__saveSignaturesFromCache, 500)

  _onChange: =>
    @setState @_getStateFromStores()

  _getStateFromStores: ->
    accounts = AccountStore.items()
    selectedAccountId = @state.selectedAccountId
    currentSignature = @state.currentSignature
    if not @state.selectedAccountId in _.pluck(accounts, "id")
      selectedAccountId = null
      currentSignature = ""
    return {accounts, selectedAccountId, currentSignature}

  _renderAccountPicker: ->
    options = @state.accounts.map (account) ->
      <option value={account.id}>{account.emailAddress}</option>

    <select value={@state.selectedAccountId} onChange={@_onSelectAccount}>
      {options}
    </select>

  _renderCurrentSignature: ->
    <Contenteditable
       ref="signatureInput"
       value={@state.currentSignature}
       onChange={@_onEditSignature}
       spellcheck={false} />

  _onEditSignature: (event) =>
    html = event.target.value
    @setState currentSignature: html
    @_saveSignatureSoon(@state.selectedAccountId, html)

  _configKey: (accountId) ->
    "nylas.account-#{accountId}.signature"

  _onSelectAccount: (event) =>
    @_saveSignatureNow(@state.selectedAccountId, @state.currentSignature)
    selectedAccountId = event.target.value
    key = @_configKey(selectedAccountId)
    initialSig = @props.config.get(key) ? ""
    @setState
      currentSignature: initialSig
      selectedAccountId: selectedAccountId

  render: =>
    <div className="container-signatures">
      <div className="section-title">
        Signature for: {@_renderAccountPicker()}
      </div>
      <div className="signature-wrap">
        {@_renderCurrentSignature()}
      </div>
    </div>

module.exports = PreferencesSignatures
