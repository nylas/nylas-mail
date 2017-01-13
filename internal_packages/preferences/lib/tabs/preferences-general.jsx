/* eslint global-require: 0*/
import React from 'react';

import {Actions} from 'nylas-exports'
import ConfigSchemaItem from './config-schema-item';
import WorkspaceSection from './workspace-section';
import SendingSection from './sending-section';
class PreferencesGeneral extends React.Component {
  static displayName = 'PreferencesGeneral'

  static propTypes = {
    config: React.PropTypes.object,
    configSchema: React.PropTypes.object,
  };

  _reboot = () => {
    const app = require('electron').remote.app;
    app.relaunch()
    app.quit()
  }


  _resetAccountsAndSettings = () => {
    const rimraf = require('rimraf')
    rimraf(NylasEnv.getConfigDirPath(), {disableGlob: true}, (err) => {
      if (err) console.log(err)
      else this._reboot()
    })
  }

  _resetEmailCache = () => {
    Actions.resetEmailCache()
  }

  render() {
    return (
      <div className="container-general" style={{maxWidth: 600}}>

        <WorkspaceSection config={this.props.config} configSchema={this.props.configSchema} />

        <ConfigSchemaItem
          configSchema={this.props.configSchema.properties.notifications}
          keyName="Notifications"
          keyPath="core.notifications"
          config={this.props.config}
        />

        <div className="platform-note platform-linux-only">
          N1 desktop notifications on Linux require Zenity. You may need to install
          it with your package manager (i.e., <code>sudo apt-get install zenity</code>).
        </div>

        <ConfigSchemaItem
          configSchema={this.props.configSchema.properties.reading}
          keyName="Reading"
          keyPath="core.reading"
          config={this.props.config}
        />

        <ConfigSchemaItem
          configSchema={this.props.configSchema.properties.composing}
          keyName="Composing"
          keyPath="core.composing"
          config={this.props.config}
        />

        <SendingSection
          config={this.props.config}
          configSchema={this.props.configSchema}
        />

        <ConfigSchemaItem
          configSchema={this.props.configSchema.properties.attachments}
          keyName="Attachments"
          keyPath="core.attachments"
          config={this.props.config}
        />

        <div className="local-data">
          <h6>Local Data</h6>
          <div className="btn" onClick={this._resetEmailCache}>Reset Email Cache</div>
          <div className="btn" onClick={this._resetAccountsAndSettings}>Reset Accounts and Settings</div>
        </div>
      </div>
    )
  }
}


export default PreferencesGeneral;
