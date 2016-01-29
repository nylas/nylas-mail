React = require 'react'
crypto = require 'crypto'
classNames = require 'classnames'
{Actions} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'
SidebarActions = require '../sidebar-actions'


ItemTypes = {
  "Unified"
}

class AccountSwitcher extends React.Component
  @displayName: 'AccountSwitcher'

  @containerRequired: false
  @containerStyles:
    minWidth: 165
    maxWidth: 210

  @propTypes:
    accounts: React.PropTypes.array.isRequired
    focusedAccounts: React.PropTypes.array.isRequired

  constructor: (@props) ->
    @state =
      showing: false

  # Helpers

  _makeItem: (account = {}) =>
    {id, label, emailAddress, provider} = account
    id ?= ItemTypes.Unified
    label ?= "All Accounts"
    email = emailAddress ? ""
    iconName = provider ? 'unified'
    accounts = if id is ItemTypes.Unified
      @props.accounts
    else
      [account]

    return {id, label, email, iconName, accounts}

  _selectedItem: =>
    if @props.focusedAccounts.length > 1
      @_makeItem()
    else
      @_makeItem(@props.focusedAccounts[0])

  _toggleDropdown: =>
    @setState showing: !@state.showing


  # Handlers

  _onBlur: (e) =>
    target = e.nativeEvent.relatedTarget
    if target? and React.findDOMNode(@refs.button).contains(target)
      return
    @setState(showing: false)

  _onSwitchAccount: (item) =>
    SidebarActions.focusAccounts(item.accounts)
    @setState(showing: false)

  _onManageAccounts: =>
    Actions.switchPreferencesTab('Accounts')
    Actions.openPreferences()

    @setState(showing: false)

  _renderItem: (item) =>
    classes = classNames
      "active": item.id is @_selectedItem().id
      "item": true
      "secondary-item": true

    <div key={item.email} className={classes} onClick={@_onSwitchAccount.bind(@, item)}>
      {@_renderGravatar(item)}
      <div className="name" style={lineHeight: "110%"}>{item.label}</div>
      <div style={clear: "both"}></div>
    </div>

  _renderManageAccountsItem: =>
    <div className="item secondary-item new-account-option"
         onClick={@_onManageAccounts}
         tabIndex={999}>
      <div style={float: 'left'}>
        <RetinaImg name="icon-accounts-addnew.png"
                   fallback="ic-settings-account-imap.png"
                   mode={RetinaImg.Mode.ContentPreserve}
                   style={width: 28, height: 28, marginTop: -10} />
      </div>
      <div className="name" style={lineHeight: "110%", textTransform: 'none'}>
        Manage accounts&hellip;
      </div>
      <div style={clear: "both"}></div>
    </div>

  _renderDropdown: (items) =>
    <div className="dropdown">
      <div className="inner">
        {items.map(@_renderItem)}
        {@_renderManageAccountsItem()}
      </div>
    </div>

  _renderGravatar: ({email, iconName}) =>
    if email
      hash = crypto.createHash('md5').update(email, 'utf8').digest('hex')
      url = "url(http://www.gravatar.com/avatar/#{hash}?d=blank&s=56)"
    else
      url = ''

    <div style={float: 'left', position: "relative"}>
      <div className="gravatar" style={backgroundImage:url}></div>
      <RetinaImg name={"ic-settings-account-#{iconName}@2x.png"}
                 style={width: 28, height: 28, marginTop: -10}
                 fallback="ic-settings-account-imap.png"
                 mode={RetinaImg.Mode.ContentPreserve} />
    </div>

  _renderPrimaryItem: (item) =>
    <div className="item primary-item" onClick={@_toggleDropdown}>
      {@_renderGravatar(item)}
      <div style={float: 'right', marginTop: -2}>
        <RetinaImg className="toggle"
                   name="account-switcher-dropdown.png"
                   mode={RetinaImg.Mode.ContentDark} />
      </div>
      <div className="name" style={lineHeight: "110%"}>
        {item.label}
      </div>
      <div style={clear: "both"}></div>
    </div>

  render: =>
    return <span /> unless @props.focusedAccounts
    classnames = ""
    classnames += "open" if @state.showing
    selected = @_selectedItem()
    if @props.accounts.length is 1
      items = @props.accounts.map(@_makeItem)
    else
      items = [@_makeItem()].concat @props.accounts.map(@_makeItem)

    <div id="account-switcher"
         tabIndex={-1}
         onBlur={@_onBlur}
         ref="button"
         className={classnames}>
      {@_renderPrimaryItem(selected)}
      {@_renderDropdown(items)}
    </div>


module.exports = AccountSwitcher
