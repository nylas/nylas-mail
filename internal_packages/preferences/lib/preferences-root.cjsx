React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox, ConfigPropContainer, ScrollRegion} = require 'nylas-component-kit'
{PreferencesSectionStore} = require 'nylas-exports'

PreferencesSidebar = require './preferences-sidebar'

class PreferencesRoot extends React.Component
  @displayName: 'PreferencesRoot'
  @containerRequired: false

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    @unlisteners = []
    @unlisteners.push PreferencesSectionStore.listen =>
      @setState(@getStateFromStores())

  componentWillUnmount: =>
    unlisten() for unlisten in @unlisteners

  getStateFromStores: =>
    sections: PreferencesSectionStore.sections()
    activeSectionId: PreferencesSectionStore.activeSectionId()

  render: =>
    section = _.find @state.sections, ({sectionId}) => sectionId is @state.activeSectionId

    if section
      bodyElement = <section.component />
    else
      bodyElement = <div>No Section Active</div>

    <Flexbox direction="row" className="preferences-wrap">
      <PreferencesSidebar sections={@state.sections}
                          activeSectionId={@state.activeSectionId} />
      <ScrollRegion className="preferences-content">
        <ConfigPropContainer>{bodyElement}</ConfigPropContainer>
      </ScrollRegion>
    </Flexbox>

module.exports = PreferencesRoot
