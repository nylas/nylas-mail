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

    count = []
    if @props.thread.messageMetadata and @props.thread.messageMetadata.length > 1
      count = " (#{@props.thread.messageMetadata.length})"

    chips = items.map (item, idx) ->
      if item.spacer
        <span key={idx}>...</span>
      else
        if item.name.length > 0
          if items.length > 1
            short = item.displayFirstName()
          else
            short = item.displayName()
        else
          short = item.email
        if idx < items.length-1 and not items[idx+1].spacer
          short += ", "
        <span key={idx} className="unread-#{item.unread}">{short}</span>

    <div className="participants">
      {chips}{count}
    </div>

  shouldComponentUpdate: (newProps, newState) ->
    !_.isEqual(newProps.thread, @props.thread)

  getParticipants: ->
    if @props.thread.messageMetadata
      list = []
      last = null
      for msg in @props.thread.messageMetadata
        from = msg.from[0]
        continue unless from
        if from.email isnt last
          from.unread = msg.unread
          list.push(from)
          last = from.email

    else
      list = @props.thread.participants
      return [] unless list and list instanceof Array
      me = NamespaceStore.current().emailAddress
      list = _.reject list, (p) -> p.email is me

      # Removing "Me" may remove "Me" several times due to the way
      # participants is created. If we're left with an empty array,
      # put one a "Me" back in.
      if list.length is 0
        list.push(@props.thread.participants[0])

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

