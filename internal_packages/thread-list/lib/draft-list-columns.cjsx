_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
{Actions} = require 'nylas-exports'
{InjectedComponentSet, ListTabular} = require 'nylas-component-kit'
{subject} = require './formatting-utils'


snippet = (html) =>
  return "" unless html and typeof(html) is 'string'
  try
    @draftSanitizer ?= document.createElement('div')
    @draftSanitizer.innerHTML = html[0..400]
    text = @draftSanitizer.innerText
    text[0..200]
  catch
    return ""

ParticipantsColumn = new ListTabular.Column
  name: "Participants"
  width: 200
  resolver: (draft) =>
    list = [].concat(draft.to, draft.cc, draft.bcc)

    if list.length > 0
      <div className="participants">
        {list.map (p) => <span key={p.email}>{p.displayName()}</span>}
      </div>
    else
      <div className="participants no-recipients">
        (No Recipients)
      </div>

ContentsColumn = new ListTabular.Column
  name: "Contents"
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

StatusColumn = new ListTabular.Column
  name: "State"
  resolver: (draft) =>
    <InjectedComponentSet
      inline={true}
      containersRequired={false}
      matching={role: "DraftList:DraftStatus"}
      className="draft-list-injected-state"
      exposedProps={{draft}}/>

module.exports =
  Wide: [ParticipantsColumn, ContentsColumn, StatusColumn]
