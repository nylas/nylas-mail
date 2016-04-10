import React from 'react';
import {LaunchServices, SystemStartService} from 'nylas-exports';
import ConfigSchemaItem from './config-schema-item';

class DefaultMailClientItem extends React.Component {

  constructor() {
    super();
    this.state = {defaultClient: false};
    this._services = new LaunchServices();
    if (this._services.available()) {
      this._services.isRegisteredForURLScheme('mailto', (registered) => {
        if (this._mounted) this.setState({defaultClient: registered});
      });
    }
  }

  componentDidMount() {
    this._mounted = true;
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  toggleDefaultMailClient = (event) => {
    if (this.state.defaultClient) {
      this.setState({defaultClient: false});
      this._services.resetURLScheme('mailto');
    } else {
      this.setState({defaultClient: true});
      this._services.registerForURLScheme('mailto');
    }
    event.target.blur();
  }

  render() {
    if (process.platform === "win32") return false;
    return (
      <div className="item">
        <input
          type="checkbox"
          id="default-client"
          checked={this.state.defaultClient}
          onChange={this.toggleDefaultMailClient}
        />
        <label htmlFor="default-client">Use Nylas as default mail client</label>
      </div>
    );
  }

}


class LaunchSystemStartItem extends React.Component {

  constructor() {
    super();
    this.state = {
      available: false,
      launchOnStart: false,
    };
    this._service = new SystemStartService();
  }

  componentDidMount() {
    this._mounted = true;
    this._service.checkAvailability().then((available) => {
      if (this._mounted) {
        this.setState({available});
      }
      if (!available || !this._mounted) return;
      this._service.doesLaunchOnSystemStart().then((launchOnStart) => {
        if (this._mounted) {
          this.setState({launchOnStart});
        }
      });
    });
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  _toggleLaunchOnStart = (event) => {
    if (this.state.launchOnStart) {
      this.setState({launchOnStart: false});
      this._service.dontLaunchOnSystemStart();
    } else {
      this.setState({launchOnStart: true});
      this._service.configureToLaunchOnSystemStart();
    }
    event.target.blur();
  }

  render() {
    if (!this.state.available) return false;
    return (
      <div className="item">
        <input
          type="checkbox"
          id="launch-on-start"
          checked={this.state.launchOnStart}
          onChange={this._toggleLaunchOnStart}
        />
        <label htmlFor="launch-on-start">Launch on system start</label>
      </div>
      );
  }

}

const WorkspaceSection = (props) => {
  return (
    <section>
      <DefaultMailClientItem />

      <LaunchSystemStartItem />

      <ConfigSchemaItem
        configSchema={props.configSchema.properties.workspace.properties.systemTray}
        keyPath="core.workspace.systemTray"
        config={props.config}
      />

      <ConfigSchemaItem
        configSchema={props.configSchema.properties.workspace.properties.showImportant}
        keyPath="core.workspace.showImportant"
        config={props.config}
      />

      <ConfigSchemaItem
        configSchema={props.configSchema.properties.workspace.properties.showUnreadForAllCategories}
        keyPath="core.workspace.showUnreadForAllCategories"
        config={props.config}
      />

      <ConfigSchemaItem
        configSchema={this.props.configSchema.properties.workspace.properties.use24HourClock}
        keyPath="core.workspace.use24HourClock"
        config={this.props.config}
      />

      <ConfigSchemaItem
        configSchema={props.configSchema.properties.workspace.properties.interfaceZoom}
        keyPath="core.workspace.interfaceZoom"
        config={props.config}
      />

      <div className="platform-note platform-linux-only">
        "Launch on system start" only works in XDG-compliant desktop environments.
        To enable the N1 icon in the system tray, you may need to install libappindicator1.
        (i.e., <code>sudo apt-get install libappindicator1</code>)
      </div>
    </section>
  );
}

WorkspaceSection.propTypes = {
  config: React.PropTypes.object,
  configSchema: React.PropTypes.object,
}

export default WorkspaceSection;
