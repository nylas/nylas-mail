React = require "react/addons"
FileListStore = require './file-list-store'
{MultiselectActionBar} = require 'ui-components'

module.exports =
FileSelectionBar = React.createClass
  displayName: 'FileSelectionBar'

  render: ->
    <MultiselectActionBar
      dataStore={FileListStore}
      collection="file" />
