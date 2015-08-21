React = require 'react'
_ = require 'underscore'

{AccountStore} = require 'nylas-exports'
{Menu, ButtonDropdown} = require 'nylas-component-kit'

class AccountContactField extends React.Component
  @displayName: 'AccountContactField'

  @propTypes:
    value: React.PropTypes.object
    onChange: React.PropTypes.func.isRequired

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    @unlisten = AccountStore.listen =>
      @setState(@getStateFromStores())

  componentWillUnmount: =>
    @unlisten()

  getStateFromStores: =>
    accounts: AccountStore.items()

  render: =>
    return <span></span> unless @state.accounts.length > 1

    current = _.find @state.accounts, (acct) =>
      acct.emailAddress is @props.value?.email

    if current
      currentLabel = current.me().toString()
    else
      currentLabel = "Choose an account..."

    <div className="composer-participant-field">
      <div className="composer-field-label">{"From:"}</div>
      <ButtonDropdown
        ref="dropdown"
        bordered={false}
        primaryItem={<span>{currentLabel}</span>}
        menu={@_renderMenu()}/>
    </div>

  _renderMenu: =>
    others = _.reject @state.accounts, (acct) =>
      acct.emailAddress is @props.value?.email

    <Menu items={others}
      itemKey={ (account) -> account.id }
      itemContent={ (account) -> account.me().toString() }
      onSelect={@_onChooseAccount} />

  _onChooseAccount: (account) =>
    @props.onChange(account.me())
    @refs.dropdown.toggleDropdown()


module.exports = AccountContactField
