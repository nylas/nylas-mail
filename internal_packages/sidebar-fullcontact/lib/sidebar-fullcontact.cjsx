_ = require 'underscore-plus'
React = require "react"
FullContactStore = require "./fullcontact-store"

SidebarFullContactDetails = require "./sidebar-fullcontact-details"

class SidebarFullContact extends React.Component
  @displayName: "SidebarFullContact"
  @containerStyles:
    maxWidth: 300
    minWidth: 200

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
    </div>

  _fullContact: =>
    if @state.focusedContact?.email
      return @state.fullContactCache[@state.focusedContact.email] ? {}
    else
      return {}

  _onChange: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    fullContactCache: FullContactStore.fullContactCache()
    focusedContact: FullContactStore.focusedContact()


module.exports = SidebarFullContact
