import React from 'react';

import ConfigSchemaItem from './config-schema-item';
import WorkspaceSection from './workspace-section';
import SendingSection from './sending-section';

const PreferencesGeneral = (props) => {
  return (
    <div className="container-general" style={{maxWidth: 600}}>

      <WorkspaceSection config={props.config} configSchema={props.configSchema} />

      <ConfigSchemaItem
        configSchema={props.configSchema.properties.notifications}
        keyName="Notifications"
        keyPath="core.notifications"
        config={props.config}
      />

      <div className="platform-note platform-linux-only">
        N1 desktop notifications on Linux require Zenity. You may need to install
        it with your package manager (i.e., <code>sudo apt-get install zenity</code>).
      </div>

      <ConfigSchemaItem
        configSchema={props.configSchema.properties.reading}
        keyName="Reading"
        keyPath="core.reading"
        config={props.config}
      />

      <ConfigSchemaItem
        configSchema={props.configSchema.properties.composing}
        keyName="Composing"
        keyPath="core.composing"
        config={props.config}
      />

      <SendingSection config={props.config} configSchema={props.configSchema} />

      <ConfigSchemaItem
        configSchema={props.configSchema.properties.attachments}
        keyName="Attachments"
        keyPath="core.attachments"
        config={props.config}
      />

    </div>
  );
}

PreferencesGeneral.propTypes = {
  config: React.PropTypes.object,
  configSchema: React.PropTypes.object,
};

export default PreferencesGeneral;
