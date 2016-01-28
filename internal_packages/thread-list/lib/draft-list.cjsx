_ = require 'underscore'
React = require 'react'
{Actions,
 FocusedContentStore} = require 'nylas-exports'
{ListTabular,
 FluxContainer,
 MultiselectList} = require 'nylas-component-kit'
DraftListStore = require './draft-list-store'
DraftListColumns = require './draft-list-columns'
FocusContainer = require './focus-container'
EmptyState = require './empty-state'

class DraftList extends React.Component
  @displayName: 'DraftList'

  @containerRequired: false

  render: =>
    <FluxContainer
      stores=[DraftListStore]
      getStateFromStores={ -> dataSource: DraftListStore.dataSource() }>
      <FocusContainer collection="draft">
        <MultiselectList
          columns={DraftListColumns.Wide}
          onDoubleClick={@_onDoubleClick}
          emptyComponent={EmptyState}
          keymapHandlers={@_keymapHandlers()}
          itemPropsProvider={ -> {} }
          itemHeight={39}
          className="draft-list" />
      </FocusContainer>
    </FluxContainer>

  _keymapHandlers: =>
    'core:remove-from-view': @_onRemoveFromView

  _onDoubleClick: (item) =>
    Actions.composePopoutDraft(item.clientId)

  # Additional Commands

  _onRemoveFromView: =>
    items = DraftListStore.dataSource().selection.items()
    for item in items
      Actions.destroyDraft(item.clientId)


module.exports = DraftList
