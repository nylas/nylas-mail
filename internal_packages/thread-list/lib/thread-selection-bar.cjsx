React = require "react/addons"
ThreadListStore = require './thread-list-store'
{MultiselectActionBar, FluxContainer} = require 'nylas-component-kit'

class ThreadSelectionBar extends React.Component
  @displayName: 'ThreadSelectionBar'

  render: =>
    <FluxContainer
      stores={[ThreadListStore]}
      getStateFromStores={ -> dataSource: ThreadListStore.dataSource() }>
      <MultiselectActionBar
        className="thread-list"
        collection="thread" />
    </FluxContainer>

module.exports = ThreadSelectionBar
