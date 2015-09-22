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
    return undefined if @state.accounts.length < 1

    <div id="account-switcher" tabIndex={-1} onBlur={@_onBlur} ref="button">
      {@_renderAccount(@state.account, true)}
      {@_renderDropdown()}
    </div>

  _renderAccount: (account, isPrimaryItem) =>
    classes = classNames
      "account": true
      "item": true
      "dropdown-item-padding": not isPrimaryItem
      "active": account is @state.account
      "bg-color-hover": not isPrimaryItem
      "primary-item": isPrimaryItem
      "account-option": not isPrimaryItem

    email = account.emailAddress.trim().toLowerCase()

    if isPrimaryItem
      dropdownClasses = classNames
        "account-switcher-dropdown": true,
        "account-switcher-dropdown-hidden": @state.showing

      dropdownArrow = <div style={float: 'right', marginTop: -2}>
        <RetinaImg className={dropdownClasses} name="account-switcher-dropdown.png"
        mode={RetinaImg.Mode.ContentPreserve} />
      </div>

      onClick = @_toggleDropdown

    else
      onClick = =>
        @_onSwitchAccount account

    <div className={classes}
         onClick={onClick}
         key={email}>
      <div style={float: 'left'}>
        <div className="gravatar" style={backgroundImage: @_gravatarUrl(email)}></div>
        <RetinaImg name={"ic-settings-account-#{account.provider}@2x.png"}
                   style={width: 28, height: 28, marginTop: -10}
                   fallback="ic-settings-account-imap.png"
                   mode={RetinaImg.Mode.ContentPreserve} />
      </div>
      {dropdownArrow}
      <div className="name" style={lineHeight: "110%"}>
        {email}
      </div>
      <div style={clear: "both"}>
      </div>
    </div>

  _renderNewAccountOption: =>
    <div className="account item dropdown-item-padding bg-color-hover new-account-option"
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
      <div style={clear: "both"}>
      </div>
    </div>

  _renderDropdown: =>
    display = if @state.showing then "block" else "none"
    # display = "block"

    accounts = @state.accounts.map (a) =>
      @_renderAccount(a)

    <div style={display: display}
         ref="account-switcher-dropdown"
         className="dropdown dropdown-positioning dropdown-colors">
      {accounts}
      {@_renderNewAccountOption()}
    </div>

  _toggleDropdown: =>
    @setState showing: !@state.showing

  _gravatarUrl: (email) =>
    hash = crypto.createHash('md5').update(email, 'utf8').digest('hex')
    "url(http://www.gravatar.com/avatar/#{hash}?d=blank&s=56)"

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
    require('remote').getGlobal('application').windowManager.newOnboardingWindow()
    @setState showing: false

  _getStateFromStores: =>
    accounts: AccountStore.items()
    account:  AccountStore.current()


module.exports = AccountSwitcher
