_ = require 'underscore-plus'
React = require "react"
SidebarFullContactStore = require "./fullcontact-store"
SidebarFullContactChip = require "./sidebar-fullcontact-chip.cjsx"
SidebarFullContactDetails = require "./sidebar-fullcontact-details.cjsx"

{Actions, MessageStore, NamespaceStore, ComponentRegistry} = require("inbox-exports")

module.exports =
SidebarFullContact = React.createClass

  getInitialState: ->
    messages: []
    selectedContact: null
    userData: {}

  componentDidMount: ->
    @message_store_unsubscribe = MessageStore.listen @_onChange
    @fullcontact_store_unsubscribe = SidebarFullContactStore.listen @_onChange

  componentWillUnmount: ->
    @message_store_unsubscribe()

  render: ->
    @ownerEmail = NamespaceStore.current()?.emailAddress
    thread_participants = @_getParticipants()
    if @state.messages.length == 0 or thread_participants.length == 0
      return <div></div>
    if @state.selectedContact != null
      <SidebarFullContactDetails data={@state.userData}
                                 contacts={thread_participants}
                                 selectContact={@_onSelectContact} />
    else
      <SidebarFullContactChip contacts={thread_participants}
                              selectContact={@_onSelectContact} />

  _getParticipants: ->
    participants = {}
    for msg in (@state.messages ? [])
      contacts = msg.participants()
      for contact in contacts
        if contact? and contact.email?.length > 0
          if contact.email != @ownerEmail
            participants[contact.email] = contact
    return _.values(participants)

  _onSelectContact: (email) ->
    Actions.getFullContactDetails(email)
    @setState({selectedContact: email})

  _onChange: ->
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    oldMessages = @state?.messages
    newMessages = (MessageStore.items() ? [])
    messageDiff = _.difference(_.pluck(oldMessages, 'id'), _.pluck(newMessages, 'id'))
    if messageDiff.length is 0
      messages: (MessageStore.items() ? [])
      userData: SidebarFullContactStore.getDataFromEmail(@state.selectedContact)
    else
      @oldMessages = newMessages
      messages: newMessages
      selectedContact: null
