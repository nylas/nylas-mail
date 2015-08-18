React = require 'react'
_ = require 'underscore'

class ThreadListParticipants extends React.Component
  @displayName: 'ThreadListParticipants'

  @propTypes:
    thread: React.PropTypes.object.isRequired

  shouldComponentUpdate: (nextProps) =>
    return false if nextProps.thread is @props.thread
    true

  render: =>
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

  getParticipants: =>
    makeMetadataFilterer = (toOrFrom) ->
      (msg, i, msgs) ->
        isFirstMsg = i is 0
        if msg.draft
          false
        else if isFirstMsg
          true
        else # check adjacent email uniqueness
          last = msgs[i - 1][toOrFrom][0]
          curr = msgs[i][toOrFrom][0]
          isUniqueEmail = last.email.toLowerCase() isnt curr.email.toLowerCase()
          isUniqueName = last.name isnt curr.name
          isUniqueEmail or isUniqueName

    makeMetadataMapper = (toOrFrom) ->
      (msg) ->
        msg[toOrFrom].map (contact) ->
          { contact: contact, unread: msg.unread }

    if @props.thread.metadata
      shouldOnlyShowRecipients = @props.thread.metadata.every (msg) ->
        msg.from[0]?.isMe()
      input = @props.thread.metadata
      toOrFrom = if shouldOnlyShowRecipients then "to" else "from"
      filterer = makeMetadataFilterer toOrFrom
      mapper = makeMetadataMapper toOrFrom
    else
      input = @props.thread.participants
      return [] unless input and input instanceof Array
      filterer = (contact) -> not contact.isMe()
      mapper = (contact) -> { contact: contact, unread: false }

    list = _.chain(input)
            .filter(filterer)
            .map(mapper)
            .reduce(((prevContacts, next) -> prevContacts.concat(next)), [])
            .value()

    # If no participants, we should at least add current user as sole participant
    if list.length is 0 and @props.thread.participants.length > 0
      list.push({ contact: @props.thread.participants[0], unread: false })

    # We only ever want to show three. Ben...Kevin... Marty
    # But we want the *right* three.
    if list.length > 3
      listTrimmed = [
        # Always include the first item
        list[0],
        { spacer: true },

        # Always include last two items
        list[list.length - 2],
        list[list.length - 1]
      ]
      list = listTrimmed

    list


module.exports = ThreadListParticipants
