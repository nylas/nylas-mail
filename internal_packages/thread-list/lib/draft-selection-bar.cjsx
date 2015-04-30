React = require "react/addons"
DraftListStore = require './draft-list-store'
{MultiselectActionBar} = require 'ui-components'

class DraftSelectionBar extends React.Component
  @displayName: 'DraftSelectionBar'

  render: =>
    <MultiselectActionBar
      dataStore={DraftListStore}
      className="draft-list"
      collection="draft" />


module.exports = DraftSelectionBar
