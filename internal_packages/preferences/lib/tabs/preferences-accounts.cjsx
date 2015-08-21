React = require 'react'
_ = require 'underscore'
{AccountStore, DatabaseStore, EdgehillAPI} = require 'nylas-exports'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

class PreferencesAccounts extends React.Component
  @displayName: 'PreferencesAccounts'

  @propTypes:
    config: React.PropTypes.object.isRequired

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    @unsubscribe = AccountStore.listen @_onAccountChange

  componentWillUnmount: =>
    @unsubscribe?()

  render: =>
    <div className="container-accounts">
      {@_renderAccounts()}
      <div style={textAlign:"right", marginTop: '20'}>
        <button className="btn btn-large" onClick={@_onAddAccount}>Add Account...</button>
      </div>

      {@_renderLinkedAccounts()}

      <div style={textAlign:"left", marginTop: '20'}>
        <button className="btn btn-large" onClick={@_onLogout}>Log out</button>
      </div>
    </div>

  _renderAccounts: =>
    return false unless @state.accounts

    allowUnlinking = @state.accounts.length > 1

    <div>
      <div className="section-header">
        Accounts:
      </div>
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
            <div style={textAlign:"right", marginTop:10, display: if allowUnlinking then 'inline-block' else 'none'}>
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
    require('remote').getGlobal('application').windowManager.newOnboardingWindow()

  _onAccountChange: =>
    @setState(@getStateFromStores())

  _onUnlinkAccount: (account) =>
    return [] unless @props.config

    tokens = @props.config.get('tokens') || []
    token = _.find tokens, (token) ->
      token.provider is 'nylas' and token.identifier is account.emailAddress
    tokens = _.without(tokens, token)

    DatabaseStore.unpersistModel(account).then =>
      # TODO: Delete other mail data
      EdgehillAPI.unlinkToken(token)

  _onUnlinkToken: (token) =>
    EdgehillAPI.unlinkToken(token)
    return

  _onLogout: =>
    atom.logout()


module.exports = PreferencesAccounts
