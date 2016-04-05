import React from 'react';
import {ipcRenderer} from 'electron';
import {Flexbox} from 'nylas-component-kit';

import PackageSet from './package-set';
import PackagesStore from './packages-store';
import PluginsActions from './plugins-actions';


class TabInstalled extends React.Component {

  static displayName = 'TabInstalled';

  constructor() {
    super();
    this.state = this._getStateFromStores();
  }

  componentDidMount() {
    this._unsubscribers = [];
    this._unsubscribers.push(PackagesStore.listen(this._onChange));

    PluginsActions.refreshInstalledPackages();
  }

  componentWillUnmount() {
    this._unsubscribers.forEach(unsubscribe => unsubscribe());
  }

  _getStateFromStores() {
    return {
      packages: PackagesStore.installed(),
      search: PackagesStore.installedSearchValue(),
    };
  }

  _onChange = () => {
    this.setState(this._getStateFromStores());
  }

  _onInstallPackage() {
    PluginsActions.installNewPackage();
  }

  _onCreatePackage() {
    PluginsActions.createPackage();
  }

  _onSearchChange = (event) => {
    PluginsActions.setInstalledSearchValue(event.target.value);
  }

  _onEnableDevMode() {
    ipcRenderer.send('command', 'application:toggle-dev');
  }

  render() {
    let searchEmpty = null;
    if (this.state.search.length > 0) {
      searchEmpty = "No matching packages.";
    }

    let devPackages = []
    let devEmpty = (<span>Run with debug flags enabled to load ~/.nylas/dev/packages.</span>);
    let devCTA = (<div className="btn btn-large" onClick={this._onEnableDevMode}>Enable Debug Flags</div>);

    if (NylasEnv.inDevMode()) {
      devPackages = this.state.packages.dev || [];
      devEmpty = (<span>
        {`You don't have any packages installed in ~/.nylas/dev/packages. `}
        These plugins are only loaded when you run the app with debug flags
        enabled (via the Developer menu).<br/><br/>Learn more about building
        plugins with <a href="https://nylas.com/N1/docs">our docs</a>.
      </span>);
      devCTA = (<div className="btn btn-large" onClick={this._onCreatePackage}>Create New Plugin...</div>);
    }

    return (
      <div className="installed">
        <div className="inner">
          <Flexbox className="search-container">
            <div className="btn btn-large" onClick={this._onInstallPackage}>Install Plugin...</div>
            <input
              type="text"
              className="search"
              value={this.state.search}
              onChange={this._onSearchChange}
              placeholder="Search Installed Plugins" />
          </Flexbox>
          <PackageSet
            packages={this.state.packages.user}
            title="Installed plugins"
            emptyText={searchEmpty || <span>{`You don't have any plugins installed in ~/.nylas/packages.`}</span>} />
          <PackageSet
            title="Built-in plugins"
            packages={this.state.packages.example} />
          <PackageSet
            title="Development plugins"
            packages={devPackages}
            emptyText={searchEmpty || devEmpty} />
          <div className="new-package">
            {devCTA}
          </div>
        </div>
      </div>
    );
  }

}

export default TabInstalled;
