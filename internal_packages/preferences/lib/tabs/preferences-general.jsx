import React from 'react';

import ConfigSchemaItem from './config-schema-item';
import WorkspaceSection from './workspace-section';
import SendingSection from './sending-section';

class PreferencesGeneral extends React.Component {
  static displayName = 'PreferencesGeneral';

  static propTypes = {
    config: React.PropTypes.object,
    configSchema: React.PropTypes.object,
  }

  render() {
    return (
      <div className="container-general" style={{maxWidth: 600}}>

        <WorkspaceSection config={this.props.config} configSchema={this.props.configSchema} />

        <ConfigSchemaItem
          configSchema={this.props.configSchema.properties.notifications}
          keyName="Notifications"
          keyPath="core.notifications"
          config={this.props.config} />

        <div className="platform-note platform-linux-only">
          N1 desktop notifications on Linux require Zenity. You may need to install
          it with your package manager (i.e., <code>sudo apt-get install zenity</code>).
        </div>

        <ConfigSchemaItem
          configSchema={this.props.configSchema.properties.reading}
          keyName="Reading"
          keyPath="core.reading"
          config={this.props.config} />

        <SendingSection config={this.props.config} configSchema={this.props.configSchema} />

        <ConfigSchemaItem
          configSchema={this.props.configSchema.properties.attachments}
          keyName="Attachments"
          keyPath="core.attachments"
          config={this.props.config} />

      </div>
    );
  }

}

export default PreferencesGeneral;
