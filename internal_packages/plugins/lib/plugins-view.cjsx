React = require 'react'
_ = require "underscore"
{Flexbox} = require 'nylas-component-kit'
classNames = require 'classnames'

TabsStore = require './tabs-store'
Tabs = require './tabs'

class PluginsView extends React.Component
  @displayName: 'PluginsView'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  render: =>
    PluginsTabComponent = Tabs[@state.tabIndex].component
    <div className="plugins-view">
      <PluginsTabComponent />
    </div>

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push TabsStore.listen(@_onChange)

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  _getStateFromStores: =>
    tabIndex: TabsStore.tabIndex()

  _onChange: =>
    @setState(@_getStateFromStores())

module.exports = PluginsView
