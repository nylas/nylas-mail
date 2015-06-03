React = require 'react'
_ = require "underscore"
{Flexbox} = require 'nylas-component-kit'
classNames = require 'classnames'

Tabs = require './tabs'
SettingsActions = require './settings-actions'
SettingsStore = require './settings-store'

class SettingsTabs extends React.Component
  @displayName: 'SettingsTabs'

  @propTypes:
    'onChange': React.PropTypes.Func

  @containerRequired: false
  @containerStyles:
    minWidth: 200
    maxWidth: 290

  constructor: (@props) ->
    @state = @_getStateFromStores()

  render: ->
    <ul className="settings-view-tabs">
      {@_renderItems()}
    </ul>

  _renderItems: ->
    Tabs.map ({name, key, icon}, idx) =>
      classes = classNames
        'tab': true
        'active': idx is @state.tabIndex
      <li key={key} className={classes} onClick={ => SettingsActions.selectTabIndex(idx)}>{name}</li>

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push SettingsStore.listen(@_onChange)

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  _getStateFromStores: =>
    tabIndex: SettingsStore.tabIndex()

  _onChange: =>
    @setState(@_getStateFromStores())


module.exports = SettingsTabs
