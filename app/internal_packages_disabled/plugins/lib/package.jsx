import React from 'react';
import PropTypes from 'prop-types';

import { Flexbox, RetinaImg, Switch } from 'mailspring-component-kit';
import PluginsActions from './plugins-actions';

class Package extends React.Component {
  static displayName = 'Package';

  static propTypes = {
    package: PropTypes.object.isRequired,
    showVersions: PropTypes.bool,
  };

  _onDisablePackage = () => {
    PluginsActions.disablePackage(this.props.package);
  };

  _onEnablePackage = () => {
    PluginsActions.enablePackage(this.props.package);
  };

  _onUninstallPackage = () => {
    PluginsActions.uninstallPackage(this.props.package);
  };

  _onUpdatePackage = () => {
    PluginsActions.updatePackage(this.props.package);
  };

  _onInstallPackage = () => {
    PluginsActions.installPackage(this.props.package);
  };

  _onShowPackage = () => {
    PluginsActions.showPackage(this.props.package);
  };

  render() {
    const actions = [];
    const extras = [];
    let icon = <RetinaImg name="plugin-icon-default.png" mode="ContentPreserve" />;
    let uninstallButton = null;

    if (this.props.package.icon) {
      icon = (
        <img
          src={`mailspring://${this.props.package.name}/${this.props.package.icon}`}
          alt=""
          style={{ width: 27, alignContent: 'center', objectFit: 'scale-down' }}
        />
      );
    } else if (this.props.package.theme) {
      icon = <RetinaImg name="theme-icon-default.png" mode="ContentPreserve" />;
    }

    if (this.props.package.installed) {
      if (
        ['user', 'dev', 'example'].indexOf(this.props.package.category) !== -1 &&
        !this.props.package.theme
      ) {
        if (this.props.package.enabled) {
          actions.push(
            <Switch key="disable" checked onChange={this._onDisablePackage}>
              Disable
            </Switch>
          );
        } else {
          actions.push(
            <Switch key="enable" onChange={this._onEnablePackage}>
              Enable
            </Switch>
          );
        }
      }
      if (this.props.package.category === 'user') {
        uninstallButton = (
          <div className="uninstall-plugin" onClick={this._onUninstallPackage}>
            Uninstall
          </div>
        );
      }
      if (this.props.package.category === 'dev') {
        actions.push(
          <div key="show-package" className="btn" onClick={this._onShowPackage}>
            Show...
          </div>
        );
      }
    } else if (this.props.package.installing) {
      actions.push(
        <div key="installing" className="btn">
          Installing...
        </div>
      );
    } else {
      actions.push(
        <div key="install" className="btn" onClick={this._onInstallPackage}>
          Install
        </div>
      );
    }

    const { name, description, title, version } = this.props.package;

    if (this.props.package.newerVersionAvailable) {
      extras.push(
        <div className="padded update-info">
          A newer version is available: {this.props.package.newerVersion}
          <div className="btn btn-emphasis" onClick={this._onUpdatePackage}>
            Update
          </div>
        </div>
      );
    }

    const versionLabel = this.props.showVersions ? `v${version}` : null;

    return (
      <Flexbox className="package" direction="row">
        <div className="icon-container">
          <div className="icon">{icon}</div>
        </div>
        <div className="info">
          <div style={{ display: 'flex', flexDirection: 'row' }}>
            <div className="title">
              {title || name} <span className="version">{versionLabel}</span>
            </div>
            {uninstallButton}
          </div>
          <div className="description">{description}</div>
        </div>
        <div className="actions">{actions}</div>
        {extras}
      </Flexbox>
    );
  }
}

export default Package;
