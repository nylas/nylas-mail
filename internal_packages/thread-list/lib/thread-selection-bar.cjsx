React = require "react/addons"
ThreadListStore = require './thread-list-store'
{MultiselectActionBar} = require 'ui-components'

module.exports =
ThreadSelectionBar = React.createClass
  displayName: 'ThreadSelectionBar'

  render: ->
    <MultiselectActionBar
      dataStore={ThreadListStore}
      className="thread-list"
      collection="thread" />
