_ = require 'underscore'
React = require "react"
FullContactStore = require "./fullcontact-store"

{InjectedComponentSet, TimeoutTransitionGroup} = require 'nylas-component-kit'

SidebarFullContactDetails = require "./sidebar-fullcontact-details"

class SidebarFullContact extends React.Component
  @displayName: "SidebarFullContact"

  @propTypes:
    contact: React.PropTypes.object

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @unsubscribe = FullContactStore.listen(@_onChange)

  componentWillUnmount: =>
    @unsubscribe()

  render: =>
    <SidebarFullContactDetails
      contact={@props.contact}
      fullContactData={@state.focusedContactData} />

  _onChange: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    focusedContactData: FullContactStore.dataForContact(@props.contact)


module.exports = SidebarFullContact
