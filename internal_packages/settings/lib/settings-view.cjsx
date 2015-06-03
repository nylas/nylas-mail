React = require 'react'
_ = require "underscore"
{Flexbox} = require 'nylas-component-kit'
classNames = require 'classnames'

SettingsStore = require './settings-store'
Tabs = require './tabs'

class SettingsView extends React.Component
  @displayName: 'SettingsView'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  render: =>
    SettingsTabComponent = Tabs[@state.tabIndex].component
    <div className="settings-view">
      <SettingsTabComponent />
    </div>

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push SettingsStore.listen(@_onChange)

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  _getStateFromStores: =>
    tabIndex: SettingsStore.tabIndex()

  _onChange: =>
    @setState(@_getStateFromStores())


module.exports = SettingsView
