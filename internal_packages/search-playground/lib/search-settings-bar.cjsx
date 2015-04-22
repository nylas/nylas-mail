React = require 'react'
{Actions} = require 'inbox-exports'
_ = require 'underscore-plus'
SearchStore = require './search-store'

module.exports =
SearchBar = React.createClass

  getInitialState: ->
    weights: SearchStore.searchWeights()

  componentDidMount: ->
    @unsubscribe = SearchStore.listen @_onStoreChange

  componentWillUnmount: ->
    @unsubscribe()

  render: ->
    <div className="search-settings-bar">
      <div className="header">Search Weights</div>
      <div className="field">
        <strong>From:</strong>
        <input type="range" name="from" value={@state.weights.from} onChange={@_onValueChange} min="0" max="10"/>
        <input type="text" name="from" value={@state.weights.from} onChange={@_onValueChange} />
      </div>
      <div className="field">
        <strong>Subject:</strong>
        <input type="range" name="subject" value={@state.weights.subject} onChange={@_onValueChange} min="0" max="10"/>
        <input type="text" name="subject" value={@state.weights.subject} onChange={@_onValueChange} />
      </div>
    </div>

  _onValueChange: (event) ->
    weights = SearchStore.searchWeights()
    weights[event.target.name] = event.target.value
    Actions.searchWeightsChanged(weights)

  _onStoreChange: ->
    @setState
      weights: SearchStore.searchWeights()
