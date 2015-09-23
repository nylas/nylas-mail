React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox, ConfigPropContainer} = require 'nylas-component-kit'

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

  componentWillUnmount: =>
    unlisten() for unlisten in @unlisteners

  componentDidUpdate: =>
    if @state.tabs.length > 0 and not @state.activeTab
      @setState(activeTab: @state.tabs[0])

  getStateFromStores: =>
    tabs: PreferencesStore.tabs()

  render: =>
    if @state.activeTab
      bodyElement = <@state.activeTab.component config={@state.config} />
    else
      bodyElement = <div>No Tab Active</div>

    <div className="preferences-wrap">
      <PreferencesHeader tabs={@state.tabs}
                         activeTab={@state.activeTab}
                         changeActiveTab={@_onChangeActiveTab}/>
      <ConfigPropContainer>
      {bodyElement}
      </ConfigPropContainer>
      <div style={clear:'both'}></div>
    </div>

  _onChangeActiveTab: (tab) =>
    @setState(activeTab: tab)

module.exports = Preferences
