_ = require 'underscore-plus'
React = require "react"

module.exports =
MessageParticipants = React.createClass
  displayName: 'MessageParticipants'

  render: ->
    classSet = React.addons.classSet
      "participants": true
      "message-participants": true
      "collapsed": not @props.isDetailed

    <div className={classSet} onClick={@props.onClick}>
      {if @props.isDetailed then @_renderExpanded() else @_renderCollapsed()}
    </div>

  _renderCollapsed: ->
    <span className="collapsed-participants">
      <span className="participant-name from-contact">{@_shortNames(@props.from)}</span>
      <span className="participant-label to-label">&nbsp;>&nbsp;</span>
      <span className="participant-name to-contact">{@_shortNames(@props.to)}</span>
      <span style={if @props.cc.length > 0 then display:"inline" else display:"none"}>
        <span className="participant-label cc-label">Cc:&nbsp;</span>
        <span className="participant-name cc-contact">{@_shortNames(@props.cc)}</span>
      </span>
      <span style={if @props.bcc.length > 0 then display:"inline" else display:"none"}>
        <span className="participant-label bcc-label">Bcc:&nbsp;</span>
        <span className="participant-name cc-contact">{@_shortNames(@props.bcc)}</span>
      </span>
    </span>

  _renderExpanded: ->
    <div className="expanded-participants">
      <div className="participant-type">
        <div className="participant-label from-label">From:&nbsp;</div>
        <div className="participant-name from-contact">{@_fullContact(@props.from)}</div>
      </div>

      <div className="participant-type">
        <div className="participant-label to-label">To:&nbsp;</div>
        <div className="participant-name to-contact">{@_fullContact(@props.to)}</div>
      </div>

      <div className="participant-type"
           style={if @props.cc.length > 0 then display:"block" else display:"none"}>
        <div className="participant-label cc-label">Cc:&nbsp;</div>
        <div className="participant-name cc-contact">{@_fullContact(@props.cc)}</div>
      </div>

      <div className="participant-type"
           style={if @props.bcc.length > 0 then display:"block" else display:"none"}>
        <div className="participant-label bcc-label">Bcc:&nbsp;</div>
        <div className="participant-name cc-contact">{@_fullContact(@props.bcc)}</div>
      </div>
    </div>

  _shortNames: (contacts=[]) ->
    _.map(contacts, (c) -> c.displayFirstName()).join(", ")

  _fullContact: (contacts=[]) ->
    _.map(contacts, (c) ->
      if c.name?.length > 0 and c.name isnt c.email
        <div key={c.email} className="participant">
          <span className="participant-primary">{c.name}</span>&nbsp;
          <span className="participant-secondary"><{c.email}></span>
        </div>
      else
        <div key={c.email} className="participant">
          <span className="participant-primary">{c.email}</span>
        </div>
    )
