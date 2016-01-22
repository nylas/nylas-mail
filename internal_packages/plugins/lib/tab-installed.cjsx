React = require 'react'
_ = require "underscore"
PackageSet = require './package-set'
PackagesStore = require './packages-store'
PluginsActions = require './plugins-actions'
{Spinner, EventedIFrame, Flexbox} = require 'nylas-component-kit'
classNames = require 'classnames'

class TabInstalled extends React.Component
  @displayName: 'TabInstalled'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  render: =>
    searchEmpty = null
    if @state.search.length > 0
      searchEmpty = "No matching packages."

    if NylasEnv.inDevMode()
      devPackages = @state.packages.dev
      devEmpty = <span>
        You don't have any packages installed in ~/.nylas/dev/packages.
        These plugins are only loaded when you run the app with debug flags
        enabled (via the Developer menu).<br/><br/>Learn more about building
        plugins at <a href='https://nylas.com/N1/docs'>https://nylas.com/N1/docs</a>
      </span>
      devCTA = <div className="btn btn-large" onClick={@_onCreatePackage}>Create New Plugin...</div>
    else
      devPackages = []
      devEmpty = <span>Run with debug flags enabled to load ~/.nylas/dev/packages.</span>
      devCTA = <div className="btn btn-large" onClick={@_onEnableDevMode}>Enable Debug Flags</div>

    <div className="installed">
      <div className="inner">
        <input
          type="search"
          value={@state.search}
          onChange={@_onSearchChange }
          placeholder="Search Installed Plugins"/>
        <PackageSet
          packages={@state.packages.user}
          title="Third Party"
          emptyText={searchEmpty ? <span>You don't have any plugins installed in ~/.nylas/packages.</span>} />
        <PackageSet
          title="Built In"
          packages={@state.packages.example} />
        <PackageSet
          title="Development"
          packages={devPackages}
          emptyText={searchEmpty ? devEmpty} />
        <div className="new-package">
          {devCTA}
        </div>
      </div>
    </div>

  _onEnableDevMode: =>
    require('electron').ipcRenderer.send('command', 'application:toggle-dev')

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push PackagesStore.listen(@_onChange)

    PluginsActions.refreshInstalledPackages()

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  _getStateFromStores: =>
    packages: PackagesStore.installed()
    search: PackagesStore.installedSearchValue()

  _onChange: =>
    @setState(@_getStateFromStores())

  _onCreatePackage: =>
    PluginsActions.createPackage()

  _onSearchChange: (event) =>
    PluginsActions.setInstalledSearchValue(event.target.value)

module.exports = TabInstalled
