React = require 'react'
{Actions, AccountStore} = require("nylas-exports")
{RetinaImg} = require('nylas-component-kit')
crypto = require 'crypto'
classNames = require 'classnames'

class AccountSwitcher extends React.Component
  @displayName: 'AccountSwitcher'

  @containerRequired: false
  @containerStyles:
    minWidth: 64
    maxWidth: 64

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @unsubscribers = []
    @unsubscribers.push AccountStore.listen @_onStoreChange

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @unsubscribers

  render: =>
    if @state.accounts.length is 0
      return <span></span>

    <div id="account-switcher">
      {@_accounts()}
    </div>

  _accounts: =>
    return @state.accounts.map (account) =>
      hash = account.emailAddress.trim().toLowerCase()
      hash = crypto.createHash('md5').update(hash, 'utf8').digest('hex')

      classnames = classNames
        'account': true
        'active': account is @state.account

      gravatarUrl = "http://www.gravatar.com/avatar/#{hash}?d=blank&s=44"

      <div title={account.emailAddress} className={classnames} key={account.id} onClick={ => @_onSwitchAccount(account) }>
        <div style={backgroundImage: "url(#{gravatarUrl})"} className="gravatar"></div>
        <RetinaImg name={"ic-settings-account-#{account.provider}.png"}
                   style={width: 44, height: 44}
                   fallback="ic-settings-account-imap.png"
                   mode={RetinaImg.Mode.ContentPreserve} />
      </div>

  _onStoreChange: =>
    @setState @_getStateFromStores()

  _onSwitchAccount: (account) =>
    Actions.selectAccountId(account.id)

  _getStateFromStores: =>
    accounts: AccountStore.items()
    account: AccountStore.current()

module.exports = AccountSwitcher
