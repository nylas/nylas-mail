_ = require 'underscore-plus'
React = require "react"

{Actions, FocusedContactsStore} = require("inbox-exports")

module.exports =
SidebarThreadParticipants = React.createClass
  displayName: 'SidebarThreadParticipants'

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unsubscribe = FocusedContactsStore.listen @_onChange

  componentWillUnmount: ->
    @unsubscribe()

  render: ->
    <div className="sidebar-thread-participants">
      <h2 className="sidebar-h2">Thread Participants</h2>
      {@_renderSortedContacts()}
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

  _onChange: ->
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    sortedContacts: FocusedContactsStore.sortedContacts()
    focusedContact: FocusedContactsStore.focusedContact()
