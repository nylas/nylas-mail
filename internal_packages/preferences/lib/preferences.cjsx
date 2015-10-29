React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox, ConfigPropContainer} = require 'nylas-component-kit'
{PreferencesSectionStore} = require 'nylas-exports'

PreferencesHeader = require './preferences-header'

class Preferences extends React.Component
  @displayName: 'Preferences'

  constructor: (@props) ->
    tabs = PreferencesSectionStore.sections()
    if @props.initialTab
      activeTab = _.find tabs, (t) => t.name is @props.initialTab
    activeTab ||= tabs[0]

    @state = _.extend(@getStateFromStores(), {activeTab})

  componentDidMount: =>
    @unlisteners = []
    @unlisteners.push PreferencesSectionStore.listen =>
      @setState(@getStateFromStores())

  componentWillUnmount: =>
    unlisten() for unlisten in @unlisteners

  componentDidUpdate: =>
    if @state.tabs.length > 0 and not @state.activeTab
      @setState(activeTab: @state.tabs[0])

  getStateFromStores: =>
    tabs: PreferencesSectionStore.sections()

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
