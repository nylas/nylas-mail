_ = require 'underscore'
React = require 'react'
classnames = require 'classnames'

{AccountStore} = require 'nylas-exports'
{Menu, ButtonDropdown} = require 'nylas-component-kit'

class AccountContactField extends React.Component
  @displayName: 'AccountContactField'

  @propTypes:
    value: React.PropTypes.object
    accounts: React.PropTypes.array.isRequired
    onChange: React.PropTypes.func.isRequired

  _onChooseContact: (contact) =>
    @props.onChange({from: [contact]})
    @refs.dropdown.toggleDropdown()

  _renderAccountSelector: ->
    return <span /> unless @props.value
    label = @props.value.toString()
    multipleAccounts = @props.accounts.length > 1
    hasAliases = @props.accounts[0]?.aliases.length > 0
    if multipleAccounts or hasAliases
      <ButtonDropdown
        ref="dropdown"
        bordered={false}
        primaryItem={<span>{label}</span>}
        menu={@_renderAccounts(@props.accounts)} />
    else
      @_renderAccountSpan(label)

  _renderMenuItem: (contact) =>
    className = classnames(
      'contact': true
      'is-alias': contact.isAlias
    )
    <span className={className}>{contact.toString()}</span>

  _renderAccounts: (accounts) =>
    items = AccountStore.aliasesFor(accounts)
    <Menu
      items={items}
      itemKey={(contact) -> contact.id}
      itemContent={@_renderMenuItem}
      onSelect={@_onChooseContact} />

  _renderAccountSpan: (label) ->
    <span className="from-picker" style={position: "relative", top: 6, left: "0.5em"}>{label}</span>

  render: =>
    <div className="composer-participant-field">
      <div className="composer-field-label">From:</div>
      {@_renderAccountSelector()}
    </div>


module.exports = AccountContactField
