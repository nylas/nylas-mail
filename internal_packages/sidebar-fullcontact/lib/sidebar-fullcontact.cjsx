_ = require 'underscore'
React = require "react"
FullContactStore = require "./fullcontact-store"

{InjectedComponentSet} = require 'nylas-component-kit'

SidebarFullContactDetails = require "./sidebar-fullcontact-details"

class SidebarFullContact extends React.Component
  @displayName: "SidebarFullContact"
  @containerStyles:
    order: 1
    maxWidth: 300
    minWidth: 200
    flexShrink: 0

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @unsubscribe = FullContactStore.listen @_onChange

  componentWillUnmount: =>
    @unsubscribe()

  render: =>
    <div className="full-contact-sidebar">
      <SidebarFullContactDetails contact={@state.focusedContact ? {}}
                                 fullContact={@_fullContact()}/>
      <InjectedComponentSet matching={role: "sidebar:focusedContactInfo"}
                            direction="column"
                            exposedProps={focusedContact: @state.focusedContact}/>
    </div>

  _fullContact: =>
    if @state.focusedContact?.thirdPartyData
      return @state.focusedContact?.thirdPartyData["FullContact"] ? {}
    else
      return {}

  _onChange: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    focusedContact: FullContactStore.focusedContact()


module.exports = SidebarFullContact
