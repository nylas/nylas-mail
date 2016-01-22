React = require "react/addons"
ThreadListStore = require './thread-list-store'
{MultiselectActionBar} = require 'nylas-component-kit'

class ThreadSelectionBar extends React.Component
  @displayName: 'ThreadSelectionBar'

  render: =>
    <MultiselectActionBar
      dataStore={ThreadListStore}
      className="thread-list"
      collection="thread" />

module.exports = ThreadSelectionBar
