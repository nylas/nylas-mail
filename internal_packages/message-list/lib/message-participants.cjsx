_ = require 'underscore'
React = require "react"
classNames = require 'classnames'

class MessageParticipants extends React.Component
  @displayName: 'MessageParticipants'

  render: =>
    classSet = classNames
      "participants": true
      "message-participants": true
      "collapsed": not @props.isDetailed

    <div className={classSet} onClick={@props.onClick}>
      {if @props.isDetailed then @_renderExpanded() else @_renderCollapsed()}
    </div>

  _renderCollapsed: =>
    <span className="collapsed-participants">
      <span className="participant-name from-contact">{@_shortNames(@props.from)}</span>
      <span className="participant-label to-label">To:&nbsp;</span>
      <span className="participant-name to-contact">{@_shortNames(@props.to)}</span>
      <span style={if @props.cc?.length > 0 then display:"inline" else display:"none"}>
        <span className="participant-label cc-label">Cc:&nbsp;</span>
        <span className="participant-name cc-contact">{@_shortNames(@props.cc)}</span>
      </span>
      <span style={if @props.bcc?.length > 0 then display:"inline" else display:"none"}>
        <span className="participant-label bcc-label">Bcc:&nbsp;</span>
        <span className="participant-name cc-contact">{@_shortNames(@props.bcc)}</span>
      </span>
    </span>

  _renderExpanded: =>
    <div className="expanded-participants">
      <div className="participant-type">
        <div className="participant-name from-contact">{@_fullContact(@props.from)}</div>
      </div>

      <div className="participant-type">
        <div className="participant-label to-label">To:&nbsp;</div>
        <div className="participant-name to-contact">{@_fullContact(@props.to)}</div>
      </div>

      <div className="participant-type"
           style={if @props.cc?.length > 0 then display:"block" else display:"none"}>
        <div className="participant-label cc-label">Cc:&nbsp;</div>
        <div className="participant-name cc-contact">{@_fullContact(@props.cc)}</div>
      </div>

      <div className="participant-type"
           style={if @props.bcc?.length > 0 then display:"block" else display:"none"}>
        <div className="participant-label bcc-label">Bcc:&nbsp;</div>
        <div className="participant-name cc-contact">{@_fullContact(@props.bcc)}</div>
      </div>

    </div>

  _shortNames: (contacts=[]) =>
    _.map(contacts, (c) -> c.displayFirstName()).join(", ")

  _fullContact: (contacts=[]) =>
    if contacts.length is 0
      # This is necessary to make the floats work properly
      <div>&nbsp;</div>
    else
      _.map(contacts, (c, i) =>
        if contacts.length is 1 then comma = ""
        else if i is contacts.length-1 then comma = ""
        else comma = ","

        if c.name?.length > 0 and c.name isnt c.email
          <div key={c.email} className="participant selectable">
            <span className="participant-primary" onClick={@_selectPlainText}>{c.name}</span>&nbsp;
            <span className="participant-secondary" onClick={@_selectBracketedText}><{c.email}>{comma}</span>&nbsp;
          </div>
        else
          <div key={c.email} className="participant selectable">
            <span className="participant-primary" onClick={@_selectCommaText}>{c.email}{comma}</span>&nbsp;
          </div>
      )

  _selectPlainText: (e) =>
    textNode = e.currentTarget.childNodes[0]
    @_selectText(textNode)

  _selectCommaText: (e) =>
    textNode = e.currentTarget.childNodes[0].childNodes[0]
    @_selectText(textNode)

  _selectBracketedText: (e) =>
    textNode = e.currentTarget.childNodes[1].childNodes[0] # because of React rendering
    @_selectText(textNode)

  _selectText: (textNode) =>
    range = document.createRange()
    range.setStart(textNode, 0)
    range.setEnd(textNode, textNode.length)
    selection = document.getSelection()
    selection.removeAllRanges()
    selection.addRange(range)



module.exports = MessageParticipants
