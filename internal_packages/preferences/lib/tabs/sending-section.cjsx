_ = require 'underscore'
React = require 'react'
{AccountStore} = require 'nylas-exports'
ConfigSchemaItem = require './config-schema-item'

class SendingSection extends React.Component
  @displayName: 'SendingSection'
  @propTypes:
    config: React.PropTypes.object
    configSchema: React.PropTypes.object

  _getExtendedSchema: (configSchema) ->
    accounts = AccountStore.accounts()

    values = accounts.map (acc) -> acc.id
    labels = accounts.map (acc) -> acc.me().toString()

    values = [null, values...]
    labels = ['Account of selected mailbox', labels...]

    _.extend(configSchema.properties.sending.properties, {
      defaultAccountIdForSend:
        type: 'string'
        title: 'Send new messages from'
        default: null
        enum: values
        enumLabels: labels
    })

    return configSchema.properties.sending

  render: ->
    sendingSchema = @_getExtendedSchema(@props.configSchema)

    <ConfigSchemaItem
      config={@props.config}
      configSchema={sendingSchema}
      keyName="Sending"
      keyPath="core.sending" />


module.exports = SendingSection
