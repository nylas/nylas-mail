React = require "react/addons"
FileListStore = require './file-list-store'
{MultiselectActionBar} = require 'nylas-component-kit'

class FileSelectionBar extends React.Component
  @displayName: 'FileSelectionBar'

  render: =>
    <MultiselectActionBar
      dataStore={FileListStore}
      collection="file" />


module.exports = FileSelectionBar
