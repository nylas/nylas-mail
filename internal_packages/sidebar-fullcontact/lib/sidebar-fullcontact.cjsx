_ = require 'underscore-plus'
React = require "react"
FullContactStore = require "./fullcontact-store"

SidebarFullContactDetails = require "./sidebar-fullcontact-details"

module.exports =
SidebarFullContact = React.createClass

  getInitialState: ->
    fullContactCache: {}
    focusedContact: null

  componentDidMount: ->
    @unsubscribe = FullContactStore.listen @_onChange

  componentWillUnmount: ->
    @unsubscribe()

  render: ->
    <div className="full-contact-sidebar">
      <SidebarFullContactDetails contact={@state.focusedContact ? {}}
                                 fullContact={@_fullContact()}/>
    </div>

  _fullContact: ->
    if @state.focusedContact?.email
      return @state.fullContactCache[@state.focusedContact.email] ? {}
    else
      return {}

  _onChange: ->
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    fullContactCache: FullContactStore.fullContactCache()
    focusedContact: FullContactStore.focusedContact()

SidebarFullContact.maxWidth = 300
SidebarFullContact.minWidth = 200
