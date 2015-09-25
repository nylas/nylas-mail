_ = require 'underscore'
React = require "react"

{Actions, FocusedContactsStore} = require("nylas-exports")
{TimeoutTransitionGroup,
 InjectedComponentSet,
 Flexbox} = require("nylas-component-kit")

class FocusedContactStorePropsContainer extends React.Component
  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @unsubscribe = FocusedContactsStore.listen(@_onChange)

  componentWillUnmount: =>
    @unsubscribe()

  render: ->
    classname = "sidebar-section"
    if @state.focusedContact
      classname += " visible"
      inner = React.cloneElement(@props.children, @state)

    <div className={classname}>{inner}</div>

  _onChange: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    sortedContacts: FocusedContactsStore.sortedContacts()
    focusedContact: FocusedContactsStore.focusedContact()


class SidebarSpacer extends React.Component
  @displayName: 'SidebarSpacer'
  @containerStyles:
    order: 50
    flex: 1

  constructor: (@props) ->

  render: ->
    <div style={flex: 1}></div>

class SidebarContactList extends React.Component
  @displayName: 'SidebarContactList'
  @containerStyles:
    order: 100
    flexShrink: 0

  constructor: (@props) ->

  render: ->
    <FocusedContactStorePropsContainer>
      <SidebarContactListInner/>
    </FocusedContactStorePropsContainer>

class SidebarContactListInner extends React.Component
  constructor: (@props) ->

  render: ->
    <div className="sidebar-contact-list">
      <h2>Thread Participants</h2>
      {@_renderSortedContacts()}
    </div>

  _renderSortedContacts: =>
    @props.sortedContacts.map (contact) =>
      if contact.email is @props.focusedContact.email
        selected = "selected"
      else
        selected = ""

      <div className="contact #{selected}"
           onClick={=> @_onSelectContact(contact)}
           key={contact.email + contact.name}>
        {contact.name}
      </div>

  _onSelectContact: (contact) =>
    Actions.focusContact(contact)

class SidebarContactCard extends React.Component
  @displayName: 'SidebarContactCard'

  @containerStyles:
    order: 0
    flexShrink: 0
    minWidth:200
    maxWidth:300

  constructor: (@props) ->

  render: ->
    <FocusedContactStorePropsContainer>
      <SidebarContactCardInner />
    </FocusedContactStorePropsContainer>

class SidebarContactCardInner extends React.Component
  constructor: (@props) ->

  render: ->
    <InjectedComponentSet
      className="sidebar-contact-card"
      key={@props.focusedContact.email}
      matching={role: "MessageListSidebar:ContactCard"}
      direction="column"
      exposedProps={contact: @props.focusedContact}/>

module.exports = {SidebarContactCard, SidebarSpacer, SidebarContactList}
