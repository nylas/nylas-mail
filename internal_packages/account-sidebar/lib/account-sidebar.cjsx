React = require 'react'
{Actions, MailViewFilter, AccountStore} = require("nylas-exports")
{ScrollRegion} = require("nylas-component-kit")
SidebarDividerItem = require("./account-sidebar-divider-item")
SidebarSheetItem = require("./account-sidebar-sheet-item")
AccountSidebarStore = require ("./account-sidebar-store")
AccountSidebarMailViewItem = require("./account-sidebar-mail-view-item")
crypto = require 'crypto'
{RetinaImg} = require 'nylas-component-kit'
classNames = require 'classnames'

class AccountSidebar extends React.Component
  @displayName: 'AccountSidebar'

  @containerRequired: false
  @containerStyles:
    minWidth: 165
    maxWidth: 210

  constructor: (@props) ->
    @state = @_getStateFromStores()
    @state.showing = false

  componentDidMount: =>
    @unsubscribers = []
    @unsubscribers.push AccountSidebarStore.listen @_onStoreChange
    @unsubscribers.push AccountStore.listen @_onStoreChange

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @unsubscribers

  render: =>
    <ScrollRegion style={flex:1} id="account-sidebar">
      {@_accountSwitcher()}
      <div className="account-sidebar-sections">
        {@_sections()}
      </div>
    </ScrollRegion>

  _accountSwitcher: =>
    return undefined if @state.accounts.length < 1

    <div id="account-switcher" tabIndex={-1} onBlur={@_onBlur} ref="button">
      {@_renderAccount @state.account, true}
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

  _sections: =>
    return @state.sections.map (section) =>
      <section key={section.label}>
        <div className="heading">{section.label}</div>
        {@_itemComponents(section)}
      </section>

  _itemComponents: (section) =>
    section.items?.map (item) =>
      return unless item
      if item instanceof MailViewFilter
        <AccountSidebarMailViewItem
          key={item.id ? item.type}
          mailView={item}
          select={ item.isEqual(@state.selected) }/>
      else
        if item.sidebarComponent
          itemClass = item.sidebarComponent
        else
          itemClass = SidebarSheetItem

        <itemClass
          key={item.id ? item.type}
          item={item}
          sectionType={section.type}
          select={item.id is @state.selected?.id }/>

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
    sections: AccountSidebarStore.sections()
    selected: AccountSidebarStore.selected()
    accounts: AccountStore.items()
    account:  AccountStore.current()


module.exports = AccountSidebar
