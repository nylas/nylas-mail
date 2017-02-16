_ = require 'underscore'
React = require "react"
{FocusedContactsStore} = require("nylas-exports")
{InjectedComponentSet} = require("nylas-component-kit")

class FocusedContactStorePropsContainer extends React.Component
  @displayName: 'FocusedContactStorePropsContainer'

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
    focusedContactThreads: FocusedContactsStore.focusedContactThreads()

class SidebarPluginContainer extends React.Component
  @displayName: 'SidebarPluginContainer'

  @containerStyles:
    order: 1
    flexShrink: 0
    minWidth:200
    maxWidth:300

  constructor: (@props) ->

  render: ->
    <FocusedContactStorePropsContainer>
      <SidebarPluginContainerInner />
    </FocusedContactStorePropsContainer>

class SidebarPluginContainerInner extends React.Component
  constructor: (@props) ->

  render: ->
    <InjectedComponentSet
      className="sidebar-contact-card"
      key={@props.focusedContact.email}
      matching={role: "MessageListSidebar:ContactCard"}
      direction="column"
      exposedProps={contact: @props.focusedContact, contactThreads: @props.focusedContactThreads}/>

module.exports = SidebarPluginContainer
