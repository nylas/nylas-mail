React = require 'react'
_ = require 'underscore-plus'
{NamespaceStore} = require 'inbox-exports'

module.exports =
ThreadListParticipants = React.createClass
  displayName: 'ThreadListParticipants'

  propTypes:
    thread: React.PropTypes.object.isRequired
      
  render: ->
    items = @getParticipants()

    spans = []
    accumulated = null
    accumulatedUnread = false

    flush = ->
      if accumulated
        spans.push <span key={spans.length} className="unread-#{accumulatedUnread}">{accumulated}</span>
      accumulated = null
      accumulatedUnread = false

    accumulate = (text, unread) ->
      if accumulated and unread and accumulatedUnread isnt unread
        flush()
      if accumulated
        accumulated += text
      else
        accumulated = text
        accumulatedUnread = unread

    for {spacer, contact, unread}, idx in items
      if spacer
        accumulate('...')
      else
        if contact.name.length > 0
          if items.length > 1
            short = contact.displayFirstName()
          else
            short = contact.displayName()
        else
          short = contact.email
        if idx < items.length-1 and not items[idx+1].spacer
          short += ", "
        accumulate(short, unread)

    if @props.thread.metadata and @props.thread.metadata.length > 1
      accumulate(" (#{@props.thread.metadata.length})")

    flush()

    <div className="participants">
      {spans}
    </div>

  getParticipants: ->
    if @props.thread.metadata
      list = []
      last = null
      for msg in @props.thread.metadata
        from = msg.from[0]
        if from and from.email isnt last
          list.push({
            contact: msg.from[0]
            unread: msg.unread
          })
          last = from.email

    else
      list = @props.thread.participants
      return [] unless list and list instanceof Array
      me = NamespaceStore.current().emailAddress
      list = _.reject list, (p) -> p.email is me

      # Removing "Me" may remove "Me" several times due to the way
      # participants is created. If we're left with an empty array,
      # put one a "Me" back in.
      if list.length is 0 and @props.thread.participants.length > 0
        list.push(@props.thread.participants[0])

      # Change the list to have the appropriate output format
      list = list.map (contact) ->
        contact: contact
        unread: false # We don't have the data.

    # We only ever want to show three. Ben...Kevin... Marty
    # But we want the *right* three.
    if list.length > 3
      listTrimmed = []

      # Always include the first item
      listTrimmed.push(list[0])
      listTrimmed.push({spacer: true})

      # Always include the last two item
      listTrimmed.push(list[list.length - 2])
      listTrimmed.push(list[list.length - 1])
      list = listTrimmed

    list

