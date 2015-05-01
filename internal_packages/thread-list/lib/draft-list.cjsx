_ = require 'underscore-plus'
React = require 'react'
{ListTabular,
 MultiselectList,
 InjectedComponent} = require 'ui-components'
{timestamp, subject} = require './formatting-utils'
{Actions,
 DatabaseStore} = require 'inbox-exports'
DraftListStore = require './draft-list-store'

class DraftList extends React.Component
  @displayName: 'DraftList'

  @containerRequired: false

  componentWillMount: =>
    snippet = (html) =>
      @draftSanitizer ?= document.createElement('div')
      @draftSanitizer.innerHTML = html
      text = @draftSanitizer.innerText
      text[0..140]

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
      'core:remove-item': @_onDelete

  render: =>
    <MultiselectList
      dataStore={DraftListStore}
      columns={@columns}
      commands={@commands}
      onDoubleClick={@_onDoubleClick}
      itemPropsProvider={ -> {} }
      className="draft-list"
      collection="draft" />

  _onDoubleClick: (item) =>
    DatabaseStore.localIdForModel(item).then (localId) ->
      Actions.composePopoutDraft(localId)

  # Additional Commands

  _onDelete: ({focusedId}) =>
    item = @state.dataView.getById(focusedId)
    return unless item
    DatabaseStore.localIdForModel(item).then (localId) ->
      Actions.destroyDraft(localId)
    @_onShiftSelectedIndex(-1)


module.exports = DraftList
