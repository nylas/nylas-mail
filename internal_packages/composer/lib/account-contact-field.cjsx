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

    <div className="composer-participant-field">
      <div className="composer-field-label">{"From:"}</div>
      {@_renderFromPicker()}
    </div>

  _renderFromPicker: ->
    current = _.find @state.accounts, (acct) =>
      acct.emailAddress is @props.value?.email

    if current
      currentLabel = current.me().toString()
    else
      currentLabel = "Please select one of your accounts"
      # currentLabel = "Choose an account..."

    return <span className="from-picker" style={position: "relative", top: "5px", left: "0.5em"}>{currentLabel}</span>

    # <ButtonDropdown
    #   ref="dropdown"
    #   bordered={false}
    #   primaryItem={<span>{currentLabel}</span>}
    #   menu={@_renderMenu()}/>

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
