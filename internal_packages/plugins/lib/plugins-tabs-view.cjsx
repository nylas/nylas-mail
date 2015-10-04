React = require 'react'
_ = require "underscore"
{Flexbox} = require 'nylas-component-kit'
classNames = require 'classnames'

Tabs = require './tabs'
TabsStore = require './tabs-store'
PluginsActions = require './plugins-actions'

class PluginsTabs extends React.Component
  @displayName: 'PluginsTabs'

  @propTypes:
    'onChange': React.PropTypes.Func

  @containerRequired: false
  @containerStyles:
    minWidth: 200
    maxWidth: 290

  constructor: (@props) ->
    @state = @_getStateFromStores()

  render: ->
    <ul className="plugins-view-tabs">
      {@_renderItems()}
    </ul>

  _renderItems: ->
    Tabs.map ({name, key, icon}, idx) =>
      classes = classNames
        'tab': true
        'active': idx is @state.tabIndex
      <li key={key} className={classes} onClick={ => PluginsActions.selectTabIndex(idx)}>{name}</li>

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push TabsStore.listen(@_onChange)

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  _getStateFromStores: =>
    tabIndex: TabsStore.tabIndex()

  _onChange: =>
    @setState(@_getStateFromStores())


module.exports = PluginsTabs
