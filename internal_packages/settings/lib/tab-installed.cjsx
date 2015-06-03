React = require 'react'
_ = require "underscore"
PackageSet = require './package-set'
SettingsPackagesStore = require './settings-packages-store'
SettingsActions = require './settings-actions'
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

    <div className="installed">
      <div className="inner">
        <input
          type="search"
          value={@state.search}
          onChange={@_onSearchChange }
          placeholder="Search Installed Packages"/>
        <PackageSet
          packages={@state.packages.user}
          title="Community"
          emptyText={searchEmpty ? "You don't have any community packages installed"} />
        <PackageSet
          title="Core"
          packages={@state.packages.core} />
        <PackageSet
          title="Development"
          packages={@state.packages.dev}
          emptyText={searchEmpty ? "You don't have any packages in ~/.nylas/dev/packages"}   />
        <div className="new-package">
          <div className="btn btn-large" onClick={@_onCreatePackage}>Create New Package...</div>
        </div>
      </div>
    </div>

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push SettingsPackagesStore.listen(@_onChange)

    SettingsActions.refreshInstalledPackages()

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  _getStateFromStores: =>
    packages: SettingsPackagesStore.installed()
    search: SettingsPackagesStore.installedSearchValue()

  _onChange: =>
    @setState(@_getStateFromStores())

  _onCreatePackage: =>
    SettingsActions.createPackage()

  _onSearchChange: (event) =>
    SettingsActions.setInstalledSearchValue(event.target.value)

module.exports = TabInstalled
