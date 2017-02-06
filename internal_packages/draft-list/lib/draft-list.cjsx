_ = require 'underscore'
React = require 'react'
{Actions} = require 'nylas-exports'
{FluxContainer,
 FocusContainer,
 EmptyListState,
 MultiselectList} = require 'nylas-component-kit'
DraftListStore = require './draft-list-store'
DraftListColumns = require './draft-list-columns'

class DraftList extends React.Component
  @displayName: 'DraftList'
  @containerRequired: false

  render: =>
    <FluxContainer
      stores=[DraftListStore]
      getStateFromStores={ -> dataSource: DraftListStore.dataSource() }>
      <FocusContainer collection="draft">
        <MultiselectList
          className="draft-list"
          columns={DraftListColumns.Wide}
          onDoubleClick={@_onDoubleClick}
          EmptyComponent={EmptyListState}
          keymapHandlers={@_keymapHandlers()}
          itemPropsProvider={@_itemPropsProvider}
          itemHeight={39}
        />
      </FocusContainer>
    </FluxContainer>

  _itemPropsProvider: (draft) ->
    props = {}
    props.className = 'sending' if draft.uploadTaskId
    props

  _keymapHandlers: =>
    'core:delete-item': @_onRemoveFromView
    'core:gmail-remove-from-view': @_onRemoveFromView
    'core:remove-from-view': @_onRemoveFromView

  _onDoubleClick: (draft) =>
    unless draft.uploadTaskId
      Actions.composePopoutDraft(draft.clientId)

  # Additional Commands

  _onRemoveFromView: =>
    drafts = DraftListStore.dataSource().selection.items()
    Actions.destroyDraft(draft.clientId) for draft in drafts

module.exports = DraftList
