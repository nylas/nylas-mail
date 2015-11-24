React = require 'react'
_ = require 'underscore'
{AccountStore, DatabaseStore, EdgehillAPI} = require 'nylas-exports'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

class PreferencesAccounts extends React.Component
  @displayName: 'PreferencesAccounts'

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    @unsubscribe = AccountStore.listen @_onAccountChange

  componentWillUnmount: =>
    @unsubscribe?()

  render: =>
    <section className="container-accounts">
      <h2>Accounts</h2>
      {@_renderAccounts()}
      <div style={textAlign:"right", marginTop: '20'}>
        <button className="btn btn-large" onClick={@_onAddAccount}>Add Account...</button>
      </div>

      {@_renderLinkedAccounts()}
    </section>

  _renderAccounts: =>
    return false unless @state.accounts

    <div>
      { @state.accounts.map (account) =>
        <div className="well large" style={marginBottom:10} key={account.id}>
          <Flexbox direction="row" style={alignItems: 'middle'}>
            <div style={textAlign: "center"}>
              <RetinaImg name={"ic-settings-account-#{account.provider}.png"}
                         fallback="ic-settings-account-imap.png"
                         mode={RetinaImg.Mode.ContentPreserve} />
            </div>
            <div style={flex: 1, marginLeft: 10}>
              <div className="account-name">{account.emailAddress}</div>
              <div className="account-subtext">{account.name || "No name provided."} ({account.displayProvider()})</div>
            </div>
            <div style={textAlign:"right", marginTop:10, display:'inline-block'}>
              <button className="btn btn-large" onClick={ => @_onUnlinkAccount(account) }>Unlink</button>
            </div>
          </Flexbox>
        </div>
      }
    </div>

  _renderLinkedAccounts: =>
    tokens = @getSecondaryTokens()
    return false unless tokens.length > 0
    <div>
      <div className="section-header">
        Linked Accounts:
      </div>
      { tokens.map (token) =>
        <div className="well small" key={token.id}>
          {@_renderLinkedAccount(token)}
        </div>
      }
    </div>

  _renderLinkedAccount: (token) =>
    <Flexbox direction="row" style={alignItems: "center"}>
      <div>
        <RetinaImg name={"ic-settings-account-#{token.provider}.png"} fallback="ic-settings-account-imap.png" />
      </div>
      <div style={flex: 1, marginLeft: 10}>
        <div className="account-name">{token.provider}</div>
      </div>
      <div style={textAlign:"right"}>
        <button onClick={ => @_onUnlinkToken(token) } className="btn btn-large">Unlink</button>
      </div>
    </Flexbox>

  getStateFromStores: =>
    accounts: AccountStore.items()

  getSecondaryTokens: =>
    return [] unless @props.config
    tokens = @props.config.get('tokens') || []
    tokens = tokens.filter (token) -> token.provider isnt 'nylas'
    tokens

  _onAddAccount: =>
    ipc = require('electron').ipcRenderer
    ipc.send('command', 'application:add-account')

  _onAccountChange: =>
    @setState(@getStateFromStores())

  _onUnlinkAccount: (account) =>
    AccountStore.removeAccountId(account.id)

  _onUnlinkToken: (token) =>

module.exports = PreferencesAccounts
