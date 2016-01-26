_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'

{ListTabular, InjectedComponent} = require 'nylas-component-kit'
{timestamp,
 subject} = require './formatting-utils'

snippet = (html) =>
  return "" unless html and typeof(html) is 'string'
  try
    @draftSanitizer ?= document.createElement('div')
    @draftSanitizer.innerHTML = html[0..400]
    text = @draftSanitizer.innerText
    text[0..200]
  catch
    return ""

c1 = new ListTabular.Column
  name: "Name"
  width: 200
  resolver: (draft) =>
    <div className="participants">
      <InjectedComponent matching={role:"Participants"}
                         exposedProps={participants: [].concat(draft.to, draft.cc, draft.bcc), clickable: false}/>
    </div>

c2 = new ListTabular.Column
  name: "Message"
  flex: 4
  resolver: (draft) =>
    attachments = []
    if draft.files?.length > 0
      attachments = <div className="thread-icon thread-icon-attachment"></div>
    <span className="details">
      <span className="subject">{subject(draft.subject)}</span>
      <span className="snippet">{snippet(draft.body)}</span>
      {attachments}
    </span>

c3 = new ListTabular.Column
  name: "Date"
  flex: 1
  resolver: (draft) =>
    <span className="timestamp">{timestamp(draft.date)}</span>

module.exports =
  Wide: [c1, c2, c3]
