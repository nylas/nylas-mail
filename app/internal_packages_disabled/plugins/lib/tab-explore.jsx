import React from 'react';

import PackageSet from './package-set';
import PackagesStore from './packages-store';
import PluginsActions from './plugins-actions';

class TabExplore extends React.Component {
  static displayName = 'TabExplore';

  constructor() {
    super();
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    this._unsubscribers = [];
    this._unsubscribers.push(PackagesStore.listen(this._onChange));

    // Trigger a refresh of the featured packages
    PluginsActions.refreshFeaturedPackages();
  }

  componentWillUnmount() {
    this._unsubscribers.forEach(unsubscribe => unsubscribe());
  }

  _getStateFromStores() {
    return {
      featured: PackagesStore.featured(),
      search: PackagesStore.globalSearchValue(),
      searchResults: PackagesStore.searchResults(),
    };
  }

  _onChange = () => {
    this.setState(this._getStateFromStores());
  };

  _onSearchChange = event => {
    PluginsActions.setGlobalSearchValue(event.target.value);
  };

  render() {
    let collection = this.state.featured;
    let collectionPrefix = 'Featured ';
    let emptyText = null;
    if (this.state.search.length > 0) {
      collectionPrefix = 'Matching ';
      if (this.state.searchResults) {
        collection = this.state.searchResults;
        emptyText = 'No results found.';
      } else {
        collection = {
          packages: [],
          themes: [],
        };
        emptyText = 'Loading results...';
      }
    }

    return (
      <div className="explore">
        <div className="inner">
          <input
            type="text"
            className="search"
            value={this.state.search}
            onChange={this._onSearchChange}
            placeholder="Search Packages and Themes"
          />
          <PackageSet
            title={`${collectionPrefix} Themes`}
            emptyText={emptyText || 'There are no featured themes yet.'}
            packages={collection.themes}
          />
          <PackageSet
            title={`${collectionPrefix} Packages`}
            emptyText={emptyText || 'There are no featured packages yet.'}
            packages={collection.packages}
          />
        </div>
      </div>
    );
  }
}

export default TabExplore;
