_ = require 'underscore'
React = require 'react'
{Actions, Utils} = require 'nylas-exports'
{InjectedComponentSet, ListTabular} = require 'nylas-component-kit'


snippet = (html) =>
  return "" unless html and typeof(html) is 'string'
  try
    text = Utils.extractTextFromHtml(html, maxLength: 400)
    text[0..200]
  catch
    return ""

subject = (subj) ->
  if (subj ? "").trim().length is 0
    return <span className="no-subject">(No Subject)</span>
  else
    return subj

ParticipantsColumn = new ListTabular.Column
  name: "Participants"
  width: 200
  resolver: (draft) =>
    list = [].concat(draft.to, draft.cc, draft.bcc)

    if list.length > 0
      <div className="participants">
        <span>{list.map((p) => p.displayName()).join(', ')}</span>
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
