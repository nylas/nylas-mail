React = require 'react'
_ = require 'underscore'

{AccountStore} = require 'nylas-exports'
{Menu, ButtonDropdown} = require 'nylas-component-kit'

class AccountContactField extends React.Component
  @displayName: 'AccountContactField'

  @propTypes:
    value: React.PropTypes.object
    account: React.PropTypes.object,
    onChange: React.PropTypes.func.isRequired

  render: =>
    <div className="composer-participant-field">
      <div className="composer-field-label">{"From:"}</div>
      {@_renderFromPicker()}
    </div>

  _renderFromPicker: ->
    if @props.account? && @props.value?
      label = @props.value.toString()
      if @props.account.aliases.length is 0
        return @_renderAccountSpan(label)
      return <ButtonDropdown
        ref="dropdown"
        bordered={false}
        primaryItem={<span>{label}</span>}
        menu={@_renderAliasesMenu(@props.account)}/>
    else
      return @_renderAccountSpan("Please select an account")

  _renderAliasesMenu: (account) =>
    <Menu
      items={[account.me().toString()].concat account.aliases}
      itemKey={ (alias) -> alias }
      itemContent={ (alias) -> alias }
      onSelect={@_onChooseAlias.bind(@, account)} />

  _renderAccountSpan: (label) ->
    <span className="from-picker" style={position: "relative", top: 6, left: "0.5em"}>{label}</span>

  _onChooseAlias: (account, alias) =>
    @props.onChange(account.meUsingAlias(alias))
    @refs.dropdown.toggleDropdown()


module.exports = AccountContactField
