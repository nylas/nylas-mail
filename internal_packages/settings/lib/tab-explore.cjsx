React = require 'react'
_ = require "underscore"
PackageSet = require './package-set'
SettingsPackagesStore = require './settings-packages-store'
SettingsActions = require './settings-actions'
{Spinner, EventedIFrame, Flexbox} = require 'nylas-component-kit'
classNames = require 'classnames'

class TabExplore extends React.Component
  @displayName: 'TabExplore'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  render: =>
    if @state.search.length
      collectionPrefix = "Matching "
      if @state.searchResults
        collection = @state.searchResults
        emptyText = "No results found."
      else
        collection = {packages: [], themes: []}
        emptyText = "Loading results..."
    else
      collection = @state.featured
      collectionPrefix = "Featured "
      emptyText = null

    <div className="explore">
      <div className="inner">
        <input
          type="search"
          value={@state.search}
          onChange={@_onSearchChange }
          placeholder="Search Packages and Themes"/>
        <PackageSet
          title="#{collectionPrefix} Themes"
          emptyText={emptyText ? "There are no featured themes yet."}
          packages={collection.themes} />
        <PackageSet
          title="#{collectionPrefix} Packages"
          emptyText={emptyText ? "There are no featured packages yet."}
          packages={collection.packages} />
      </div>
    </div>

  componentDidMount: =>
    @_unsubscribers = []
    @_unsubscribers.push SettingsPackagesStore.listen(@_onChange)

    # Trigger a refresh of the featured packages
    SettingsActions.refreshFeaturedPackages()

  componentWillUnmount: =>
    unsubscribe() for unsubscribe in @_unsubscribers

  _getStateFromStores: =>
    featured: SettingsPackagesStore.featured()
    search: SettingsPackagesStore.globalSearchValue()
    searchResults: SettingsPackagesStore.searchResults()

  _onChange: =>
    @setState(@_getStateFromStores())

  _onSearchChange: (event) =>
    SettingsActions.setGlobalSearchValue(event.target.value)


module.exports = TabExplore
