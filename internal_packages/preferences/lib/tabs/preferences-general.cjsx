React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox} = require 'nylas-component-kit'
{AccountStore} = require 'nylas-exports'

ConfigSchemaItem = require './config-schema-item'
WorkspaceSection = require './workspace-section'

class PreferencesGeneral extends React.Component
  @displayName: 'PreferencesGeneral'

  render: =>
    <div className="container" style={maxWidth:600}>

      <WorkspaceSection config={@props.config} configSchema={@props.configSchema} />

      <ConfigSchemaItem
        configSchema={@props.configSchema.properties.notifications}
        keyName="Notifications"
        keyPath="core.notifications"
        config={@props.config} />

      <ConfigSchemaItem
        configSchema={@props.configSchema.properties.reading}
        keyName="Reading"
        keyPath="core.reading"
        config={@props.config} />

      <ConfigSchemaItem
        configSchema={@props.configSchema.properties.sending}
        keyName="Sending"
        keyPath="core.sending"
        config={@props.config} />

      <ConfigSchemaItem
        configSchema={@props.configSchema.properties.attachments}
        keyName="Attachments"
        keyPath="core.attachments"
        config={@props.config} />

    </div>

module.exports = PreferencesGeneral
