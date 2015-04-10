React = require "react/addons"
DraftListStore = require './draft-list-store'
{MultiselectActionBar} = require 'ui-components'

module.exports =
DraftSelectionBar = React.createClass
  displayName: 'DraftSelectionBar'

  render: ->
    <MultiselectActionBar
      dataStore={DraftListStore}
      className="draft-list"
      collection="draft" />
