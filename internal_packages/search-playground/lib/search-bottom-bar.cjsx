React = require 'react'
_ = require 'underscore-plus'
PlaygroundActions = require './playground-actions'

module.exports =
SearchBottomBar = React.createClass

  render: ->
    <div className="search-bottom-bar">
      <button onClick={@_onClear} className="btn">Clear Ranking</button>
      <button onClick={@_onSubmit} className="btn btn-emphasis">Submit Ranking</button>
    </div>

  _onClear: ->
    PlaygroundActions.clearRanks()

  _onSubmit: ->
    PlaygroundActions.submitRanks()
