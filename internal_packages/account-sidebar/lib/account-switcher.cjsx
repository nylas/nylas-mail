React = require 'react'
{Actions, AccountStore} = require("nylas-exports")
{ScrollRegion} = require("nylas-component-kit")
crypto = require 'crypto'
{RetinaImg} = require 'nylas-component-kit'
classNames = require 'classnames'

class AccountSwitcher extends React.Component
  @displayName: 'AccountSwitcher'

  constructor: (@props) ->
    @state = @_getStateFromStores()
    @state.showing = false

  componentDidMount: =>
    @unsubscribers = []
    @unsubscribers.push AccountStore.listen @_onStoreChange

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @unsubscribers

  render: =>
    return false unless @state.account

    classnames = ""
    classnames += "open" if @state.showing

    <div id="account-switcher"
         tabIndex={-1}
         onBlur={@_onBlur}
         ref="button"
         className={classnames}>
      {@_renderPrimaryItem()}
      {@_renderDropdown()}
    </div>

  _renderPrimaryItem: =>
    <div className="item primary-item" onClick={@_toggleDropdown}>
      {@_renderGravatarForAccount(@state.account)}
      <div style={float: 'right', marginTop: -2}>
        <RetinaImg className="toggle"
                   name="account-switcher-dropdown.png"
                   mode={RetinaImg.Mode.ContentPreserve} />
      </div>
      <div className="name" style={lineHeight: "110%"}>
        {@state.account.emailAddress.trim().toLowerCase()}
      </div>
      <div style={clear: "both"}></div>
    </div>

  _renderAccount: (account) =>
    email = account.emailAddress.trim().toLowerCase()
    classes = classNames
      "active": account is @state.account
      "item": true
      "secondary-item": true

    <div className={classes} onClick={ => @_onSwitchAccount(account)} key={email}>
      {@_renderGravatarForAccount(account)}
      <div className="name" style={lineHeight: "110%"}>{email}</div>
      <div style={clear: "both"}></div>
    </div>

  _renderNewAccountOption: =>
    <div className="item secondary-item new-account-option"
         onClick={@_onAddAccount}
         tabIndex={999}>
      <div style={float: 'left'}>
        <RetinaImg name="icon-accounts-addnew.png"
                   fallback="ic-settings-account-imap.png"
                   mode={RetinaImg.Mode.ContentPreserve}
                   style={width: 28, height: 28, marginTop: -10} />
      </div>
      <div className="name" style={lineHeight: "110%", textTransform: 'none'}>
        Add account&hellip;
      </div>
      <div style={clear: "both"}></div>
    </div>

  _renderDropdown: =>
    <div className="dropdown">
      <div className="inner">
        {@state.accounts.map(@_renderAccount)}
        {@_renderNewAccountOption()}
      </div>
    </div>

  _renderGravatarForAccount: (account) =>
    email = account.emailAddress.trim().toLowerCase()
    hash = crypto.createHash('md5').update(email, 'utf8').digest('hex')
    url = "url(http://www.gravatar.com/avatar/#{hash}?d=blank&s=56)"

    <div style={float: 'left', position: "relative"}>
      <div className="gravatar" style={backgroundImage:url}></div>
      <RetinaImg name={"ic-settings-account-#{account.provider}@2x.png"}
                 style={width: 28, height: 28, marginTop: -10}
                 fallback="ic-settings-account-imap.png"
                 mode={RetinaImg.Mode.ContentPreserve} />
    </div>

  _toggleDropdown: =>
    @setState showing: !@state.showing

  _onStoreChange: =>
    @setState @_getStateFromStores()

  _onBlur: (e) =>
    target = e.nativeEvent.relatedTarget
    if target? and React.findDOMNode(@refs.button).contains(target)
      return
    @setState(showing: false)

  _onSwitchAccount: (account) =>
    Actions.selectAccountId(account.id)
    @setState(showing: false)

  _onAddAccount: =>
    require('ipc').send('command', 'application:add-account')
    @setState(showing: false)

  _getStateFromStores: =>
    accounts: AccountStore.items()
    account:  AccountStore.current()

module.exports = AccountSwitcher
