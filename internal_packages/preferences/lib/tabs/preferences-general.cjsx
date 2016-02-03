React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox} = require 'nylas-component-kit'
{AccountStore} = require 'nylas-exports'

ConfigSchemaItem = require './config-schema-item'
WorkspaceSection = require './workspace-section'
SendingSection = require './sending-section'

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

      <div className="platform-note platform-linux-only">
        N1 desktop notifications on Linux require Zenity. You may need to install
        it with your package manager (ie: <code>sudo apt-get install zenity</code>)
      </div>

      <ConfigSchemaItem
        configSchema={@props.configSchema.properties.reading}
        keyName="Reading"
        keyPath="core.reading"
        config={@props.config} />

      <SendingSection config={@props.config} configSchema={@props.configSchema} />

      <ConfigSchemaItem
        configSchema={@props.configSchema.properties.attachments}
        keyName="Attachments"
        keyPath="core.attachments"
        config={@props.config} />

    </div>

module.exports = PreferencesGeneral
