_ = require 'underscore-plus'
moment = require "moment"
React = require 'react'
{ListTabular} = require 'ui-components'
{timestamp, subject} = require './formatting-utils'
{Actions,
 DraftStore,
 ComponentRegistry,
 DatabaseStore} = require 'inbox-exports'

module.exports =
DraftList = React.createClass
  displayName: 'DraftList'

  mixins: [ComponentRegistry.Mixin]
  components: ['Participants']

  getInitialState: ->
    items: DraftStore.items()
    columns: @_computeColumns()
    selectedId: null
 
  componentDidMount: ->
    @draft_store_unsubscribe = DraftStore.listen @_onChange
    @body_unsubscriber = atom.commands.add 'body',
      'application:previous-item': => @_onShiftSelectedIndex(-1)
      'application:next-item': => @_onShiftSelectedIndex(1)
      'application:remove-item': @_onDeleteSelected

  componentWillUnmount: ->
    @draft_store_unsubscribe()
    @body_unsubscriber.dispose()

  render: ->
    <div className="thread-list">
      <ListTabular
        columns={@state.columns}
        items={@state.items}
        selectedId={@state.selectedId}
        onClick={@_onClick}
        onSelect={@_onSelect} />
    </div>

  _onSelect: (item) ->
    @setState
      selectedId: item.id

  _onClick: (item) ->
    DatabaseStore.localIdForModel(item).then (localId) ->
      Actions.composePopoutDraft(localId)

  _computeColumns: ->
    c1 = new ListTabular.Column
      name: "Name"
      flex: 2
      resolver: (draft) =>
        Participants = @state.Participants
        <div className="participants">
          <Participants participants={[].concat(draft.to,draft.cc,draft.bcc)}
                        context={'list'} clickable={false} />
        </div>

    c2 = new ListTabular.Column
      name: "Subject"
      flex: 3
      resolver: (draft) ->
        <span className="subject">{subject(draft.subject)}</span>

    c3 = new ListTabular.Column
      name: "Snippet"
      flex: 4
      resolver: (draft) ->
        <span className="snippet">{draft.body}</span>

    c4 = new ListTabular.Column
      name: "Date"
      flex: 1
      resolver: (draft) ->
        <span className="timestamp">{timestamp(draft.date)}</span>

    [c1, c2, c3, c4]

  _onShiftSelectedIndex: (delta) ->
    item = _.find @state.items, (draft) => draft.id is @state.selectedId
    index = if item then @state.items.indexOf(item) else -1
    index = Math.max(0, Math.min(index + delta, @state.items.length-1))
    @setState
      selectedId: @state.items[index].id

  _onDeleteSelected: ->
    item = _.find @state.items, (draft) => draft.id is @state.selectedId

    DatabaseStore.localIdForModel(item).then (localId) ->
      Actions.destroyDraft(localId)
    @_onShiftSelectedIndex(-1)

  _onChange: ->
    @setState
      items: DraftStore.items()
