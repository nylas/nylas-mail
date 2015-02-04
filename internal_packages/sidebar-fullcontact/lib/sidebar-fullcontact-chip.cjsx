_ = require 'underscore-plus'
React = require "react"

{Actions} = require 'inbox-exports'

module.exports =
SidebarFullContactChip = React.createClass

  render: ->
    <div className="fullcontact-chips">
      {
        for contact in @props.contacts
          if contact.name != contact.email
            @_makeContactChip(contact, @props.compact)
      }
      {
        for contact in @props.contacts
          if contact.name == contact.email
            @_makeContactChip(contact, @props.compact)
      }
    </div>

  _makeContactChip: (contact, compact) ->
    if contact.name == contact.email or compact == true
      <div className="fullcontact-chip" onClick={=>@props.selectContact(contact.email)} >
        <h6>{contact.email}</h6>
      </div>
    else
      <div className="fullcontact-chip" onClick={=>@props.selectContact(contact.email)} >
        {
          if compact != true
            <h3>{contact.name}</h3>
        }
        <h6>{contact.email}</h6>
      </div>
