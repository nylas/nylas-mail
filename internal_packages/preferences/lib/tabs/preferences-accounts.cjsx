React = require 'react'
_ = require 'underscore'
{NamespaceStore} = require 'nylas-exports'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

class PreferencesAccounts extends React.Component
  @displayName: 'PreferencesAccounts'

  @propTypes:
    config: React.PropTypes.object.isRequired

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    @unsubscribe = NamespaceStore.listen @_onNamespaceChange

  componentWillUnmount: =>
    @unsubscribe?()

  render: =>
    <div className="container-accounts">
      <div className="section-header">
        Account:
      </div>
      <div className="well large">
        {@_renderNamespace()}
      </div>

      {@_renderLinkedAccounts()}
    </div>

  _renderNamespace: =>
    return false unless @state.namespace

    <Flexbox direction="row" style={alignItems: 'middle'}>
      <div style={textAlign: "center"}>
        <RetinaImg name={"ic-settings-account-#{@state.namespace.provider}.png"}
                   fallback="ic-settings-account-imap.png"
                   mode={RetinaImg.Mode.ContentPreserve} />
      </div>
      <div style={flex: 1, marginLeft: 10}>
        <div className="account-name">{@state.namespace.emailAddress}</div>
        <div className="account-subtext">{@state.namespace.name || "No name provided."} ({@state.namespace.displayProvider()})</div>
      </div>
      <div style={textAlign:"right"}>
        <button className="btn btn-larger" onClick={@_onLogout}>Log out</button>
      </div>
    </Flexbox>

  _renderLinkedAccounts: =>
    accounts = @getLinkedAccounts()
    return false unless accounts.length > 0
    <div>
      <div className="section-header">
        Linked Accounts:
      </div>
      { accounts.map (name) =>
        <div className="well small" key={name}>
          {@_renderLinkedAccount(name)}
        </div>
      }
    </div>

  _renderLinkedAccount: (name) =>
    <Flexbox direction="row" style={alignItems: "center"}>
      <div>
        <RetinaImg name={"ic-settings-account-#{name}.png"} fallback="ic-settings-account-imap.png" />
      </div>
      <div style={flex: 1, marginLeft: 10}>
        <div className="account-name">{name}</div>
      </div>
      <div style={textAlign:"right"}>
        <button onClick={ => @_onUnlinkAccount(name) } className="btn btn-large">Unlink</button>
      </div>
    </Flexbox>

  getStateFromStores: =>
    namespace: NamespaceStore.current()

  getLinkedAccounts: =>
    return [] unless @props.config
    accounts = []
    for key in ['salesforce']
      accounts.push(key) if @props.config[key]
    accounts

  _onNamespaceChange: =>
    @setState(@getStateFromStores())

  _onUnlinkAccount: (name) =>
    atom.config.unset(name)
    return

  _onLogout: =>
    atom.logout()


module.exports = PreferencesAccounts
