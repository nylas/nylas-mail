_ = require 'underscore'
React = require "react"
classnames = require 'classnames'
{Contact} = require 'nylas-exports'


MAX_COLLAPSED = 5

class MessageParticipants extends React.Component
  @displayName: 'MessageParticipants'

  @propTypes:
    to: React.PropTypes.array
    cc: React.PropTypes.array
    bcc: React.PropTypes.array
    from: React.PropTypes.array
    onClick: React.PropTypes.func
    isDetailed: React.PropTypes.bool

  @defaultProps:
    to: []
    cc: []
    bcc: []
    from: []


  # Helpers

  _allToParticipants: =>
    _.union(@props.to, @props.cc, @props.bcc)

  _selectText: (e) =>
    textNode = e.currentTarget.childNodes[0]

    range = document.createRange()
    range.setStart(textNode, 0)
    range.setEnd(textNode, textNode.length)
    selection = document.getSelection()
    selection.removeAllRanges()
    selection.addRange(range)

  _shortNames: (contacts = [], max = MAX_COLLAPSED) =>
    names = _.map(contacts, (c) -> c.displayName(includeAccountLabel: true, compact: true))
    if names.length > max
      extra = names.length - max
      names = names.slice(0, max)
      names.push("and #{extra} more")
    names.join(", ")

  # Renderers

  _renderFullContacts: (contacts = []) =>
    _.map(contacts, (c, i) =>
      if contacts.length is 1 then comma = ""
      else if i is contacts.length-1 then comma = ""
      else comma = ","

      if c.name?.length > 0 and c.name isnt c.email
        <div key={"#{c.email}-#{i}"} className="participant selectable">
          <div className="participant-primary" onClick={@_selectText}>
            {c.name}
          </div>
          <div className="participant-secondary">
            {"<"}<span onClick={@_selectText}>{c.email}</span>{">#{comma}"}
          </div>
        </div>
      else
        <div key={"#{c.email}-#{i}"} className="participant selectable">
          <div className="participant-primary">
            <span onClick={@_selectText}>{c.email}</span>{comma}
          </div>
        </div>
    )

  _renderExpandedField: (name, field, {includeLabel} = {}) =>
    includeLabel ?= true
    <div className="participant-type" key={"participant-type-#{name}"}>
      {
        if includeLabel
          <div className={"participant-label #{name}-label"}>{name}:&nbsp;</div>
        else
          undefined
      }
      <div className={"participant-name #{name}-contact"}>
        {@_renderFullContacts(field)}
      </div>
    </div>

  _renderExpanded: =>
    expanded = []

    if @props.from.length > 0
      expanded.push(
        @_renderExpandedField('from', @props.from, includeLabel: false)
      )

    if @props.to.length > 0
      expanded.push(
        @_renderExpandedField('to', @props.to)
      )

    if @props.cc.length > 0
      expanded.push(
        @_renderExpandedField('cc', @props.cc)
      )

    if @props.bcc.length > 0
      expanded.push(
        @_renderExpandedField('bcc', @props.bcc)
      )

    <div className="expanded-participants">
      {expanded}
    </div>

  _renderCollapsed: =>
    childSpans = []
    toParticipants = @_allToParticipants()

    if @props.from.length > 0
      childSpans.push(
        <span className="participant-name from-contact" key="from">{@_shortNames(@props.from)}</span>
      )

    if toParticipants.length > 0
      childSpans.push(
        <span className="participant-label to-label" key="to-label">To:&nbsp;</span>
        <span className="participant-name to-contact" key="to-value">{@_shortNames(toParticipants)}</span>
      )

    <span className="collapsed-participants">
      {childSpans}
    </span>

  render: =>
    classSet = classnames
      "participants": true
      "message-participants": true
      "collapsed": not @props.isDetailed
      "from-participants": @props.from.length > 0
      "to-participants": @_allToParticipants().length > 0

    <div className={classSet} onClick={@props.onClick}>
      {if @props.isDetailed then @_renderExpanded() else @_renderCollapsed()}
    </div>

module.exports = MessageParticipants
