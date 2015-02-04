React = require 'react'
{Actions} = require 'inbox-exports'
_ = require 'underscore-plus'
SearchSuggestionStore = require './search-suggestion-store'

module.exports =
SearchBar = React.createClass

  getInitialState: ->
    constants: SearchSuggestionStore.searchConstants()
    showing: false

  componentDidMount: ->
    @unsubscribe = SearchSuggestionStore.listen @_onStoreChange
    
  componentWillUnmount: ->
    @unsubscribe()

  render: ->
    containerClass = if @state.showing then "showing" else "hidden"
    <div className={containerClass}>
      <div className="field">
      <strong>From:</strong>
      <input type="range" name="from" value={@state.constants.from} onChange={@_onValueChange} min="0" max="10"/>
      </div>
      <div className="field">
      <strong>Subject:</strong>
      <input type="range" name="subject" value={@state.constants.subject} onChange={@_onValueChange} min="0" max="10"/>
      </div>
    </div>


  _onValueChange: (event) ->
    constants = SearchSuggestionStore.searchConstants()
    constants[event.target.name] = event.target.value
    Actions.searchConstantsChanged(constants)

  _onStoreChange: ->
    @setState
      showing: SearchSuggestionStore.query()?.length > 0
      constants: SearchSuggestionStore.searchConstants()
