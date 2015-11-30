React = require 'react'
_ = require 'underscore'
{RetinaImg,
 Flexbox,
 ConfigPropContainer,
 ScrollRegion} = require 'nylas-component-kit'
{PreferencesUIStore} = require 'nylas-exports'

PreferencesSidebar = require './preferences-sidebar'

class PreferencesRoot extends React.Component
  @displayName: 'PreferencesRoot'
  @containerRequired: false

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    @unlisteners = []
    @unlisteners.push PreferencesUIStore.listen =>
      @setState(@getStateFromStores())

  componentWillUnmount: =>
    unlisten() for unlisten in @unlisteners

  getStateFromStores: =>
    tabs: PreferencesUIStore.tabs()
    selection: PreferencesUIStore.selection()

  render: =>
    tabId = @state.selection.get('tabId')
    tab = @state.tabs.find (s) => s.tabId is tabId

    if tab
      bodyElement = <tab.component accountId={@state.selection.get('accountId')} />
    else
      bodyElement = <div></div>

    <Flexbox direction="row" className="preferences-wrap">
      <PreferencesSidebar tabs={@state.tabs}
                          selection={@state.selection} />
      <ScrollRegion className="preferences-content">
        <ConfigPropContainer>{bodyElement}</ConfigPropContainer>
      </ScrollRegion>
    </Flexbox>

module.exports = PreferencesRoot
