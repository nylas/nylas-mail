import _ from 'underscore';
import React from 'react';
import {AccountStore} from 'nylas-exports';
import ConfigSchemaItem from './config-schema-item';


class SendingSection extends React.Component {

  static displayName = 'SendingSection';

  static propTypes = {
    config: React.PropTypes.object,
    configSchema: React.PropTypes.object,
  }

  _getExtendedSchema(configSchema) {
    const accounts = AccountStore.accounts();

    let values = accounts.map(acc => acc.id);
    let labels = accounts.map(acc => acc.me().toString());

    values = ['selected-mailbox'].concat(values);
    labels = ['Account of selected mailbox'].concat(labels);

    _.extend(configSchema.properties.sending.properties, {
      defaultAccountIdForSend: {
        'type': 'string',
        'title': 'Send new messages from',
        'default': 'selected-mailbox',
        'enum': values,
        'enumLabels': labels,
      },
    });

    return configSchema.properties.sending;
  }

  render() {
    const sendingSchema = this._getExtendedSchema(this.props.configSchema);

    return (
      <ConfigSchemaItem
        config={this.props.config}
        configSchema={sendingSchema}
        keyName="Sending"
        keyPath="core.sending"
      />
    );
  }

}

export default SendingSection;
