import _ from 'underscore';
import React from 'react';
import {AccountStore, SendActionsStore} from 'nylas-exports';
import {ListensToFluxStore} from 'nylas-component-kit';
import ConfigSchemaItem from './config-schema-item';


function getExtendedSendingSchema(configSchema) {
  const accounts = AccountStore.accounts();
  // const sendActions = SendActionsStore.sendActions()
  const defaultAccountIdForSend = {
    'type': 'string',
    'title': 'Send new messages from',
    'default': 'selected-mailbox',
    'enum': ['selected-mailbox'].concat(accounts.map(acc => acc.id)),
    'enumLabels': ['Account of selected mailbox'].concat(accounts.map(acc => acc.me().toString())),
  }
  // const defaultSendType = {
  //   'type': 'string',
  //   'default': 'send',
  //   'enum': sendActions.map(({configKey}) => configKey),
  //   'enumLabels': sendActions.map(({title}) => title),
  //   'title': "Default send behavior",
  // }

  _.extend(configSchema.properties.sending.properties, {
    defaultAccountIdForSend,
  });
  return configSchema.properties.sending;
}

function SendingSection(props) {
  const {config, sendingConfigSchema} = props

  return (
    <ConfigSchemaItem
      config={config}
      configSchema={sendingConfigSchema}
      keyName="Sending"
      keyPath="core.sending"
    />
  );
}

SendingSection.displayName = 'SendingSection';
SendingSection.propTypes = {
  config: React.PropTypes.object,
  configSchema: React.PropTypes.object,
  sendingConfigSchema: React.PropTypes.object,
}

export default ListensToFluxStore(SendingSection, {
  stores: [AccountStore, SendActionsStore],
  getStateFromStores(props) {
    const {configSchema} = props
    return {
      sendingConfigSchema: getExtendedSendingSchema(configSchema),
    }
  },
});
