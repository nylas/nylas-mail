_ = require 'underscore-plus'
moment = require "moment"
{Actions} = require 'inbox-exports'

module.exports =
ThreadListItemMixin =
  threadTime: ->
    moment(@props.thread.lastMessageTimestamp).format(@_timeFormat())

  _timeFormat: ->
    diff = @_today().diff(@props.thread.lastMessageTimestamp, 'days', true)
    if diff <= 1
      return "h:mm a"
    else if diff > 1 and diff <= 365
      return "MMM D"
    else
      return "MMM D YYYY"

  # Stubbable for testing. Returns a `moment`
  _today: -> moment()

  _subject: ->
    str = @props.thread.subject
    str = "No Subject" unless str
    str

  _snippet: ->
    snip = @props.thread?.snippet ? ""
    snip = snip.replace(/(\r\n|\n|\r)/gm, "")
    if snip.length > 160
      "#{snip.slice(0, Math.min(snip.length, 160))}…"
    else snip

  _isStarred: ->
    @props.thread.isStarred()

  _toggleStar: ->
    @props.thread.toggleStar()

  _onClick: (event) ->
    event.preventDefault()
    Actions.selectThreadId(@props.thread.id)
