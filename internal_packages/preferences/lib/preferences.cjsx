React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

PreferencesStore = require './preferences-store'
PreferencesHeader = require './preferences-header'

class Preferences extends React.Component
  @displayName: 'Preferences'

  constructor: (@props) ->
    @state = _.extend @getStateFromStores(),
      activeTab: PreferencesStore.tabs()[0]

  componentDidMount: =>
    @unlisteners = []
    @unlisteners.push PreferencesStore.listen =>
      @setState(@getStateFromStores())
    @unlisteners.push atom.config.observe null, (val) =>
      @setState(@getStateFromStores())

  componentWillUnmount: =>
    unlisten() for unlisten in @unlisteners

  componentDidUpdate: =>
    if @state.tabs.length > 0 and not @state.activeTab
      @setState(activeTab: @state.tabs[0])

  getStateFromStores: =>
    config: @getConfigWithMutators()
    tabs: PreferencesStore.tabs()

  getConfigWithMutators: =>
    _.extend atom.config.get(), {
      get: (key) =>
        atom.config.get(key)
      set: (key, value) =>
        atom.config.set(key, value)
        return
      toggle: (key) =>
        atom.config.set(key, !atom.config.get(key))
        return
      contains: (key, val) =>
        vals = atom.config.get(key)
        return false unless vals and vals instanceof Array
        return val in vals
      toggleContains: (key, val) =>
        vals = atom.config.get(key)
        vals = [] unless vals and vals instanceof Array
        if val in vals
          atom.config.set(key, _.without(vals, val))
        else
          atom.config.set(key, vals.concat([val]))
        return
    }

  render: =>
    if @state.activeTab
      bodyElement = <@state.activeTab.component config={@state.config} />
    else
      bodyElement = <div>No Tab Active</div>

    <div className="preferences-wrap">
      <PreferencesHeader tabs={@state.tabs}
                         activeTab={@state.activeTab}
                         changeActiveTab={@_onChangeActiveTab}/>
      {bodyElement}
      <div style={clear:'both'}></div>
    </div>

  _onChangeActiveTab: (tab) =>
    @setState(activeTab: tab)

module.exports = Preferences
