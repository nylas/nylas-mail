React = require 'react'
{Utils} = require 'nylas-exports'
_ = require 'underscore'

class ThreadListParticipants extends React.Component
  @displayName: 'ThreadListParticipants'

  @propTypes:
    thread: React.PropTypes.object.isRequired

  shouldComponentUpdate: (nextProps) =>
    return false if nextProps.thread is @props.thread
    true

  render: =>
    items = @getTokens()
    <div className="participants">
      {@renderSpans(items)}
    </div>

  renderSpans: (items) =>
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
            short = contact.displayName(includeAccountLabel: false, compact: true)
          else
            short = contact.displayName(includeAccountLabel: false)
        else
          short = contact.email
        if idx < items.length-1 and not items[idx+1].spacer
          short += ", "
        accumulate(short, unread)

    if @props.thread.metadata and @props.thread.metadata.length > 1
      accumulate(" (#{@props.thread.metadata.length})")

    flush()

    return spans

  getTokensFromMetadata: =>
    messages = @props.thread.metadata
    tokens = []

    field = 'from'
    if (messages.every (message) -> message.isFromMe())
      field = 'to'

    for message, idx in messages
      if message.draft
        continue

      for contact in message[field]
        if tokens.length is 0
          tokens.push({ contact: contact, unread: message.unread })
        else
          lastToken = tokens[tokens.length - 1]
          lastContact = lastToken.contact

          sameEmail = Utils.emailIsEquivalent(lastContact.email, contact.email)
          sameName = lastContact.name is contact.name
          if sameEmail and sameName
            lastToken.unread ||= message.unread
          else
            tokens.push({ contact: contact, unread: message.unread })

    tokens

  getTokensFromParticipants: =>
    contacts = @props.thread.participants ? []
    contacts = contacts.filter (contact) -> not contact.isMe()
    contacts.map (contact) -> { contact: contact, unread: false }

  getTokens: =>
    if @props.thread.metadata instanceof Array
      list = @getTokensFromMetadata()
    else
      list = @getTokensFromParticipants()

    # If no participants, we should at least add current user as sole participant
    if list.length is 0 and @props.thread.participants?.length > 0
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
