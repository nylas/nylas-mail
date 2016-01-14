_ = require 'underscore'
React = require 'react'
{ListTabular,
 MultiselectList,
 InjectedComponent} = require 'nylas-component-kit'
{timestamp, subject} = require './formatting-utils'
{Actions,
 FocusedContentStore,
 DatabaseStore} = require 'nylas-exports'
DraftListStore = require './draft-list-store'
EmptyState = require './empty-state'

class DraftList extends React.Component
  @displayName: 'DraftList'

  @containerRequired: false

  componentWillMount: =>
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

    @columns = [c1, c2, c3]
    @commands =
      'core:remove-from-view': @_onRemoveFromView

  render: =>
    <MultiselectList
      dataStore={DraftListStore}
      columns={@columns}
      commands={@commands}
      onDoubleClick={@_onDoubleClick}
      emptyComponent={EmptyState}
      itemPropsProvider={ -> {} }
      itemHeight={39}
      className="draft-list"
      collection="draft" />

  _onDoubleClick: (item) =>
    Actions.composePopoutDraft(item.clientId)

  # Additional Commands

  _onRemoveFromView: =>
    items = DraftListStore.dataSource().selection.items()
    for item in items
      Actions.destroyDraft(item.clientId)


module.exports = DraftList
