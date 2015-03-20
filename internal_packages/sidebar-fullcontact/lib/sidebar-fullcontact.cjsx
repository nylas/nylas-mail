_ = require 'underscore-plus'
React = require "react"
FullContactStore = require "./fullcontact-store"

SidebarFullContactDetails = require "./sidebar-fullcontact-details.cjsx"

{Actions} = require("inbox-exports")

module.exports =
SidebarFullContact = React.createClass

  getInitialState: ->
    fullContactCache: {}
    sortedContacts: []
    focusedContact: null

  componentDidMount: ->
    @unsubscribe = FullContactStore.listen @_onChange

  componentWillUnmount: ->
    @unsubscribe()

  render: ->
    <div className="full-contact-sidebar">
      <SidebarFullContactDetails contact={@state.focusedContact ? {}}
                                 fullContact={@_fullContact()}/>
      <div className="other-contacts">
        <h2 className="sidebar-h2">Thread Participants</h2>
        {@_renderSortedContacts()}
      </div>
    </div>

  _renderSortedContacts: ->
    contacts = []
    @state.sortedContacts.forEach (contact) =>
      if contact is @state.focusedContact
        selected = "selected"
      else selected = ""
      contacts.push(
        <div className="other-contact #{selected}"
             onClick={=> @_onSelectContact(contact)}
             key={contact.id}>
          {contact.name}
        </div>
      )
    return contacts

  _onSelectContact: (contact) ->
    Actions.focusContact(contact)

  _fullContact: ->
    if @state.focusedContact?.email
      return @state.fullContactCache[@state.focusedContact.email] ? {}
    else
      return {}

  _onChange: ->
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    fullContactCache: FullContactStore.fullContactCache()
    sortedContacts: FullContactStore.sortedContacts()
    focusedContact: FullContactStore.focusedContact()
