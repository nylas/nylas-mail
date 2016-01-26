React = require "react/addons"
DraftListStore = require './draft-list-store'
{MultiselectActionBar, FluxContainer} = require 'nylas-component-kit'

class DraftSelectionBar extends React.Component
  @displayName: 'DraftSelectionBar'

  render: =>
    <FluxContainer
      stores={[DraftListStore]}
      getStateFromStores={ ->
        dataSource: DraftListStore.dataSource()
      }>
      <MultiselectActionBar
        className="draft-list"
        collection="draft" />
    </FluxContainer>

module.exports = DraftSelectionBar
