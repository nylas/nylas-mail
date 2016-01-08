React = require 'react'
_ = require 'underscore'
{Contenteditable, RetinaImg, Flexbox} = require 'nylas-component-kit'
{AccountStore, Utils} = require 'nylas-exports'

class PreferencesSignatures extends React.Component
  @displayName: 'PreferencesSignatures'

  constructor: (@props) ->
    @_signatureSaveQueue = {}

    # TODO check initally selected account
    selectedAccountId = AccountStore.accounts()[0].id
    if selectedAccountId
      key = @_configKey(selectedAccountId)
      initialSig = @props.config.get(key)
    else
      initialSig = ""

    @state =
      editAsHTML: false
      accounts: AccountStore.accounts()
      currentSignature: initialSig
      selectedAccountId: selectedAccountId

  componentDidMount: ->
    @usub = AccountStore.listen @_onChange

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
    accounts = AccountStore.accounts()
    selectedAccountId = @state.selectedAccountId
    currentSignature = @state.currentSignature
    if not @state.selectedAccountId in _.pluck(accounts, "id")
      selectedAccountId = null
      currentSignature = ""
    return {accounts, selectedAccountId, currentSignature}

  _renderAccountPicker: ->
    options = @state.accounts.map (account) ->
      <option value={account.id} key={account.id}>{account.emailAddress}</option>

    <select value={@state.selectedAccountId} onChange={@_onSelectAccount}>
      {options}
    </select>

  _renderEditableSignature: ->
    <Contenteditable
       tabIndex={-1}
       ref="signatureInput"
       value={@state.currentSignature}
       onChange={@_onEditSignature}
       spellcheck={false} />

  _renderHTMLSignature: ->
    <textarea ref="signatureHTMLInput"
              value={@state.currentSignature}
              onChange={@_onEditSignature}/>

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

  _renderModeToggle: ->
    if @state.editAsHTML
      return <a onClick={=> @setState(editAsHTML: false); return}>Edit live preview</a>
    else
      return <a onClick={=> @setState(editAsHTML: true); return}>Edit raw HTML</a>

  render: =>
    rawText = if @state.editAsHTML then "Raw HTML " else ""
    <section className="container-signatures">
      <h2>Signatures</h2>
      <div className="section-title">
        {rawText}Signature for: {@_renderAccountPicker()}
      </div>
      <div className="signature-wrap">
        {if @state.editAsHTML then @_renderHTMLSignature() else @_renderEditableSignature()}
      </div>
      <div className="toggle-mode" style={marginTop: "1em"}>{@_renderModeToggle()}</div>
    </section>

module.exports = PreferencesSignatures
